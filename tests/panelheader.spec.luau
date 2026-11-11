--!strict
-- Package A review (owner 2026-11-10, one home for a thing): a HUD panel's header (Hud/PanelHeader) says its value
-- while the panel is folded. An open panel's body says it in words ("Zostało 12:34" under "☾ Krwawy Księżyc 12:34",
-- the boss's HP on its bar under "45%", "Zapisy do 20:45" under "20:45"), so the open header leaves it out. Where the
-- body does not say it, the caller keeps it (`KeepValue`): the quest tracker's group summaries ("2/5 · 5:12") and a
-- live tourney's level band.

local fs = require("@lune/fs")

local FusionGraph = require("./FusionGraph")
local T = require("./Test")

local HUD = "src/client/UI/Screens/Hud/"

local function has(path: string, literal: string): boolean
	return string.find(fs.readFile(path), literal, 1, true) ~= nil
end

T.describe("HUD panel headers (package A review, owner 2026-11-10)", function()
	T.it("the header shows its value while folded, open only where the caller keeps it", function()
		local graph = FusionGraph.new()
		local s = graph.scope
		graph.stubs["src/client/UI/Device"] = { Touch = s:Value(false) }
		graph.stubs["src/client/UI/PhoneLayout"] = { Compact = s:Value(false) }
		graph.stubs["src/client/UI/Components/InfoTip"] = {}
		graph.stubs["src/client/UI/Sounds"] = {}
		graph.stubs["src/client/UI/Theme"] = { Size = { MinTouch = 44 } }
		local PanelHeader = graph.require(HUD .. "PanelHeader")
		T.expect(PanelHeader.showsValue("12:34", false, nil)).toBe(true)
		T.expect(PanelHeader.showsValue("12:34", true, nil)).toBe(false)
		T.expect(PanelHeader.showsValue("12:34", true, false)).toBe(false)
		T.expect(PanelHeader.showsValue("2/5 · 5:12", true, true)).toBe(true)
		T.expect(PanelHeader.showsValue("", false, true)).toBe(false)
		T.expect(PanelHeader.showsValue(nil, false, true)).toBe(false)
		T.expect(graph.errors).toEqual({})
		-- the header's line reads the rule with the panel's open state
		T.expect(
			has(
				HUD .. "PanelHeader.luau",
				"PanelHeader.showsValue(text, use(openProp) == true, if keepProp then use(keepProp) else nil)"
			)
		).toBe(true)
	end)

	T.it("the event panels let the open body say the value; the tracker's groups and a live tourney keep it", function()
		for _, file in { "BloodMoonPanel", "WorldEventPanel", "WorldBossPanel", "ArenaPanel" } do
			local path = HUD .. file .. ".luau"
			local seen = { file = file, header = has(path, "PanelHeader.new("), keeps = has(path, "KeepValue") }
			T.expect(seen).toEqual({ file = file, header = true, keeps = false })
		end
		T.expect(has(HUD .. "QuestTracker.luau", "KeepValue = true,")).toBe(true)
		local tourney = fs.readFile(HUD .. "TourneyPanel.luau")
		T.expect(string.find(tourney, "KeepValue = scope:Computed(function(use): boolean", 1, true) ~= nil).toBe(true)
		T.expect(string.find(tourney, 'return use(kind) == "live"', 1, true) ~= nil).toBe(true)
	end)
end)
