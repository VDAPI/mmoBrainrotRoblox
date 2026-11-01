--!strict
-- 2026-11-01: emotes on Roblox's own R15 animations (Data/Emotes `clip`, Logic/EmoteClip): which emotes have a clip,
-- the ids, how a clip plays and when an emote starts on it instead of its procedural motion.

local ClipFit = require("../src/shared/Logic/ClipFit")
local EmoteClip = require("../src/shared/Logic/EmoteClip")
local Emotes = require("../src/shared/Data/Emotes")
local Locomotion = require("../src/shared/Data/Locomotion")
local T = require("./Test")

-- Roblox's R15 emotes of the default Animate script that match an emote of the game (laugh and the three dances do
-- not: the game has no such emotes).
local ROBLOX = {
	wave = "rbxassetid://507770239",
	point = "rbxassetid://507770453",
	cheer = "rbxassetid://507770677",
}

local function emote(clip: any, loop: boolean?): Emotes.Emote
	return {
		id = "test",
		aliases = { "test" },
		clip = clip,
		motion = {
			keys = { { t = 0.5, pose = {} } },
			recover = 0.4,
			loop = if loop then { from = 0.1, to = 0.5 } else nil,
		},
	} :: any
end

T.describe("Emote clips: the data", function()
	T.it("wave, point and cheer play Roblox's R15 emotes; the other emotes stay procedural", function()
		for _, e in Emotes.list do
			T.expect({ e.id, EmoteClip.id(e) }).toEqual({ e.id, ROBLOX[e.id] })
		end
		T.expect(EmoteClip.ids()).toEqual({ ROBLOX.wave, ROBLOX.point, ROBLOX.cheer })
	end)

	T.it("every clip is a valid animation id, none a locomotion clip of the character", function()
		local walking: { [string]: boolean } = {}
		for _, id in Locomotion.fallback :: any do
			if type(id) == "string" then
				walking[id] = true
			end
		end
		for _, id in EmoteClip.ids() do
			T.expect({ id, ClipFit.validId(id), walking[id] }).toEqual({ id, true, nil })
		end
	end)

	T.it("an emote with a clip still has its procedural motion (the fallback)", function()
		for _, e in Emotes.list do
			if EmoteClip.id(e) then
				T.expect({ e.id, #e.motion.keys > 0, e.motion.recover > 0 }).toEqual({ e.id, true, true })
			end
		end
	end)
end)

T.describe("Emote clips: ids and plans", function()
	T.it("reads nil, 0 and anything but a positive whole number as no clip", function()
		T.expect(EmoteClip.id(emote(nil))).toBeNil()
		T.expect(EmoteClip.id(emote(0))).toBeNil()
		T.expect(EmoteClip.id(emote(-5))).toBeNil()
		T.expect(EmoteClip.id(emote(12.5))).toBeNil()
		T.expect(EmoteClip.id(emote(0 / 0))).toBeNil()
		T.expect(EmoteClip.id(emote(math.huge))).toBeNil()
		T.expect(EmoteClip.id(emote("507770239"))).toBeNil()
		T.expect(EmoteClip.id(emote(123))).toBe("rbxassetid://123")
		T.expect(EmoteClip.plan(emote(0))).toBeNil()
	end)

	T.it("plays once for a short emote, looped for a held one; fades from the motion's recover", function()
		T.expect(EmoteClip.plan(emote(7))).toEqual({
			id = "rbxassetid://7",
			looped = false,
			fadeIn = EmoteClip.FADE_IN,
			fadeOut = 0.4,
		})
		local held = EmoteClip.plan(emote(7, true))
		T.expect(held and held.looped).toBe(true)
		local quick = emote(7)
		quick.motion.recover = 0.01
		local plan = EmoteClip.plan(quick)
		T.expect(plan and plan.fadeOut).toBe(EmoteClip.FADE_OUT_MIN)
	end)

	T.it("lists each id once, sorted", function()
		T.expect(EmoteClip.ids({ emote(30), emote(4), emote(30), emote(0), emote(nil) })).toEqual({
			"rbxassetid://30",
			"rbxassetid://4",
		})
		T.expect(EmoteClip.ids({})).toEqual({})
	end)
end)

T.describe("Emote clips: clip or motion", function()
	T.it("moving: walking, jumping or falling, not standing or drifting", function()
		T.expect(EmoteClip.moving(0, 0, 0)).toBe(false)
		T.expect(EmoteClip.moving(1.2, 0, 1.2)).toBe(false)
		T.expect(EmoteClip.moving(EmoteClip.MOVE_SPEED + 0.1, 0, 0)).toBe(true)
		T.expect(EmoteClip.moving(0, 0, -16)).toBe(true)
		T.expect(EmoteClip.moving(0, EmoteClip.FALL_SPEED + 1, 0)).toBe(true)
		T.expect(EmoteClip.moving(0, -(EmoteClip.FALL_SPEED + 1), 0)).toBe(true)
		T.expect(EmoteClip.moving(0, EmoteClip.FALL_SPEED - 1, 0)).toBe(false)
	end)

	T.it("starts on the clip only with one, on R15, near the camera and standing", function()
		local wave = EmoteClip.plan(assert(Emotes.get("wave")))
		local bow = EmoteClip.plan(assert(Emotes.get("bow")))
		local here = { r15 = true, near = true, moving = false }
		T.expect(EmoteClip.useClip(wave, here)).toBe(true)
		T.expect(EmoteClip.useClip(bow, here)).toBe(false)
		T.expect(EmoteClip.useClip(wave, { r15 = false, near = true, moving = false })).toBe(false)
		T.expect(EmoteClip.useClip(wave, { r15 = true, near = false, moving = false })).toBe(false)
		T.expect(EmoteClip.useClip(wave, { r15 = true, near = true, moving = true })).toBe(false)
	end)
end)
