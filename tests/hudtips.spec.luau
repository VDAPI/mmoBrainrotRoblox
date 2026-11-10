--!strict
-- Package A review (owner 2026-11-10, "too much text"): the tooltips of package A's HUD buttons that act when pressed.
-- A press held long enough for the tooltip (Components/Tooltip LONG_PRESS, Logic/PotionPress.TIP_HOLD) was reading it,
-- so its release never acts: the touch PvP toggle, the portrait's PvP dot, the Cloak of Luring, Auto Hunt and Auto
-- Potions (the potion bar and the tracker's rows keep the same rule). The touch toggle says the state the portrait's
-- dot says (UI/PvpState: the player's own switch alone said "OFF" in a red zone, where anyone may attack), and a paused
-- Cloak or Auto Potions says "paused" on its line, with the block's sentence in the details.

local fs = require("@lune/fs")

local Locale = require("../src/shared/Util/Locale")
local PotionPress = require("../src/shared/Logic/PotionPress")
local PvpRules = require("../src/shared/Logic/PvpRules")
local T = require("./Test")
local TextCaps = require("../src/shared/Logic/TextCaps")

local HUD = "src/client/UI/Screens/Hud/"
local LANGS = { "pl", "en" }

local function has(path: string, literal: string)
	if not string.find(fs.readFile(path), literal, 1, true) then
		error(`{path} has no '{literal}'`)
	end
end

T.describe("HUD buttons' tooltips (package A review, owner 2026-11-10)", function()
	T.it("a press held for the tooltip does nothing on its release", function()
		has("src/client/UI/Components/Tooltip.luau", `local LONG_PRESS = {PotionPress.TIP_HOLD}`)
		for _, file in { "PvpToggle", "init", "LureButton", "AutoGrindButton", "AutoPotionButton" } do
			local path = HUD .. file .. ".luau"
			has(path, "pressedAt = if input.UserInputType == Enum.UserInputType.Touch then os.clock() else nil")
			has(path, "local heldFor = if pressedAt then os.clock() - pressedAt else 0")
			has(path, "PotionPress.TIP_HOLD")
		end
	end)

	T.it("the touch PvP toggle says the state the portrait's dot says", function()
		local toggle = fs.readFile(HUD .. "PvpToggle.luau")
		for _, src in { toggle, fs.readFile(HUD .. "init.luau") } do
			T.expect(string.find(src, "PvpState.indicator(scope)", 1, true) ~= nil).toBe(true)
			T.expect(string.find(src, '"pvp.dot.switchingIn"', 1, true) ~= nil).toBe(true)
			T.expect(string.find(src, "`pvp.dot.{use(", 1, true) ~= nil).toBe(true)
		end
		T.expect(string.find(toggle, "pvp.state.", 1, true)).toBe(nil)
		-- every state the indicator gives has its one-line tooltip in both languages
		local states: { [string]: boolean } = {}
		for _, zone in { "green", "yellow", "red" } do
			for _, enabled in { true, false } do
				for _, pending in { true, false } do
					for _, locked in { 0, 100 } do
						states[PvpRules.indicator(enabled, zone :: any, if pending then true else nil, locked, 50)] =
							true
					end
				end
			end
		end
		for state in states do
			for _, lang in LANGS do
				local key = `pvp.dot.{state}`
				T.expect({ key, lang, Locale.has(key, lang) }).toEqual({ key, lang, true })
				local ok, why = TextCaps.check("hudTip", Locale.T(key, nil, lang))
				T.expect({ key, lang, ok, why }).toEqual({ key, lang, true, nil })
			end
		end
	end)

	T.it("a paused Cloak of Luring or Auto Potions says 'paused' on one line, the block in its details", function()
		for _, part in
			{ { file = "LureButton", key = "hud.lure" }, { file = "AutoPotionButton", key = "hud.autoPotion" } }
		do
			local path = HUD .. part.file .. ".luau"
			has(path, `Text.get(use, "{part.key}.paused")`)
			has(path, "return if reason then Text.get(use, reason) else nil")
			for _, lang in LANGS do
				local paused = Locale.T(`{part.key}.paused`, nil, lang)
				T.expect({ lang, paused, string.find(paused, "{", 1, true) ~= nil }).toEqual({ lang, paused, false })
				for _, time in
					{
						Locale.T("lure.left.s", nil, lang),
						Locale.T("lure.left.h", { h = 23, m = 59 }, lang),
						Locale.T("lure.left.d", { d = 99, h = 23 }, lang),
						Locale.T("autoPotion.forever", nil, lang),
					}
				do
					local line = Locale.T(part.key, { state = paused, time = time }, lang)
					local ok, why = TextCaps.check("hudTip", line)
					T.expect({ line, ok, why }).toEqual({ line, true, nil })
				end
			end
		end
	end)
end)
