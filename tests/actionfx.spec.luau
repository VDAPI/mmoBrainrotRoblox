--!strict
-- Template animation (owner 2026-10-26: "wyvern ... nie wypuszcza ognia", "iceElemental burst ... lodowe kolce"): the
-- effects the actions release (Data/MotionFx, Logic/ActionFx): every entry names a real style, action, anchor and piece,
-- a release lands exactly on the server's hit W, a gather ends by W, a stream starts and ends inside its action, the
-- marks sit on the keyed timeline (Logic/MotionTimeline), a one-shot fires once (never stale), every breather breathes
-- and the frost nova erupts, the element and reach come from the ability (else the kind, else its school), and an
-- attack's animation claims the gather and the release it draws. The humanoid styles (2026-10-26): every caster's
-- spell gathers and leaves from the staff or the hand at W, every nova, pool and breath of a humanoid kind releases.
local ActionFx = require("../src/shared/Logic/ActionFx")
local BipedStyles = require("../src/shared/Data/BipedStyles")
local Bosses = require("../src/shared/Data/Bosses")
local FlyerStyles = require("../src/shared/Data/FlyerStyles")
local MonsterLooks = require("../src/shared/Data/MonsterLooks")
local Monsters = require("../src/shared/Data/Monsters")
local MotionFx = require("../src/shared/Data/MotionFx")
local MotionTimeline = require("../src/shared/Logic/MotionTimeline")
local QuadStyles = require("../src/shared/Data/QuadStyles")
local RigidStyles = require("../src/shared/Data/RigidStyles")
local T = require("./Test")

local HITS = { 0.45, 0.5, 0.74, 1.2, 1.3, 1.4, 1.8, 2.2 }
local ELEMENTS = MotionFx.ELEMENTS

local function styleOf(id: string): any
	return BipedStyles.get(id) or QuadStyles.get(id) or RigidStyles.get(id) or FlyerStyles.get(id)
end

-- The hits an action is played with: a death on its own strike, the rest on the windups of the game.
local function hitsOf(name: string, action: any): { number }
	if string.sub(name, 1, 5) == "death" then
		return { action.strike }
	end
	return HITS
end

local function kindsOf(list: { MotionFx.Fx }, kind: string): { MotionFx.Fx }
	local out = {}
	for _, fx in list do
		if fx.kind == kind then
			table.insert(out, fx)
		end
	end
	return out
end

local function lookStyle(id: string, region: any): string?
	local look = MonsterLooks.get(id, region)
	return look and look.asset and look.asset.motion
end

T.describe("MotionFx data", function()
	T.it("names real styles, actions, anchors, pieces and elements", function()
		for styleId, actions in MotionFx.STYLES do
			local style = styleOf(styleId)
			T.expect(style ~= nil).toBe(true)
			for name, list in actions do
				T.expect(style.actions[name] ~= nil).toBe(true)
				T.expect(#list > 0).toBe(true)
				for _, fx in list do
					T.expect(MotionFx.KINDS[fx.kind] ~= nil).toBe(true)
					T.expect(MotionFx.ANCHORS[fx.at]).toBe(true)
					T.expect(fx.element == nil or ELEMENTS[fx.element] == true).toBe(true)
					T.expect(fx.size == nil or (fx.size > 0 and fx.size <= 3)).toBe(true)
				end
			end
		end
		for styleId, fx in MotionFx.HIT do
			T.expect(styleOf(styleId) ~= nil).toBe(true)
			T.expect(MotionFx.KINDS[fx.kind] ~= nil and MotionFx.KINDS[fx.kind].stream ~= true).toBe(true)
			T.expect(MotionFx.ANCHORS[fx.at]).toBe(true)
		end
	end)

	T.it("gives a stream an end and a one-shot none", function()
		for _, actions in MotionFx.STYLES do
			for _, list in actions do
				for _, fx in list do
					T.expect(fx.to ~= nil).toBe(MotionFx.KINDS[fx.kind].stream == true)
				end
			end
		end
	end)

	T.it("parses marks: W is the strike's end, a share of a segment otherwise, a bad mark fails", function()
		T.expect(MotionFx.mark("W").seg).toBe("S")
		T.expect(MotionFx.mark("W").u).toBe(1)
		T.expect(MotionFx.mark("F0.85").seg).toBe("F")
		T.expect(MotionFx.mark("F0.85").u).toBeNear(0.85, 1e-9)
		T.expect(function()
			MotionFx.mark("Q1")
		end).toThrow()
		T.expect(function()
			MotionFx.mark("A1.5")
		end).toThrow()
	end)
end)

T.describe("ActionFx timing", function()
	T.it("puts a mark where Logic/MotionTimeline puts a key of the same place", function()
		local action = { strike = 0.2, follow = 1.2, recover = 0.55 }
		for _, hit in HITS do
			local seg = MotionTimeline.segments(action :: any, hit)
			for _, name in { "A", "S", "F", "R" } do
				for _, u in { 0, 0.35, 1 } do
					local want = seg[name][1] + u * seg[name][2]
					T.expect(ActionFx.time(action, hit, { seg = name, u = u })).toBeNear(want, 1e-9)
				end
			end
			T.expect(ActionFx.time(action, hit, MotionFx.mark("W"))).toBeNear(hit, 1e-9)
		end
	end)

	T.it("lands every release on W, ends every gather by W, keeps every effect inside its action", function()
		for styleId, actions in MotionFx.STYLES do
			local style = styleOf(styleId)
			for name, list in actions do
				local action = style.actions[name]
				for _, hit in hitsOf(name, action) do
					local length = MotionTimeline.length(action, hit)
					for _, fx in list do
						local kind = MotionFx.KINDS[fx.kind]
						local t0, t1 = ActionFx.window(action, hit, fx)
						T.expect(t0 >= 0 and t1 <= length + 1e-9).toBe(true)
						T.expect(t1 >= t0).toBe(true)
						if kind.stream then
							T.expect(t1 > t0).toBe(true)
						end
						if kind.gather then
							T.expect(t1 <= hit + 1e-9).toBe(true)
						end
						if kind.release then
							-- the release itself starts on the hit (a stream from it, a one-shot at it)
							T.expect(t0).toBeNear(hit, 1e-9)
						end
					end
				end
			end
		end
	end)

	T.it("breathes fire for the whole stream window of the wyvern's breath, from its hit on", function()
		local style = BipedStyles.get("wyvernRegular") :: any
		local list = MotionFx.get("wyvernRegular", "breath") :: { MotionFx.Fx }
		local breath = kindsOf(list, "breath")[1]
		T.expect(breath ~= nil).toBe(true)
		local t0, t1 = ActionFx.window(style.actions.breath, 1.3, breath)
		T.expect(t0).toBeNear(1.3, 1e-9)
		T.expect(t1 - t0 >= 0.9).toBe(true)
		T.expect(#kindsOf(list, "charge")).toBe(1)
		T.expect(#kindsOf(MotionFx.get("wyvernRegular", "spit") :: { MotionFx.Fx }, "spit")).toBe(1)
		T.expect(#kindsOf(MotionFx.get("wyvern", "breath") :: { MotionFx.Fx }, "breath")).toBe(1)
	end)

	T.it("erupts ice on the ice elemental's burst and shatters it on its death", function()
		local style = BipedStyles.get("iceElemental") :: any
		local nova = kindsOf(MotionFx.get("iceElemental", "burst") :: { MotionFx.Fx }, "nova")[1]
		T.expect(nova ~= nil).toBe(true)
		local t0 = ActionFx.window(style.actions.burst, 1.4, nova)
		T.expect(t0).toBeNear(1.4, 1e-9)
		local shatter = kindsOf(MotionFx.get("iceElemental", "deathShatter") :: { MotionFx.Fx }, "shatter")[1]
		T.expect(shatter ~= nil).toBe(true)
		local action = style.actions.deathShatter
		T.expect((ActionFx.window(action, action.strike, shatter))).toBeNear(action.strike, 1e-9)
	end)

	T.it("fires a one-shot once: in the frame that crosses it, or a first frame less than LATE after it", function()
		T.expect(ActionFx.due(1, 0.9, 0.95)).toBe(false)
		T.expect(ActionFx.due(1, 0.95, 1.02)).toBe(true)
		T.expect(ActionFx.due(1, 1.02, 1.05)).toBe(false)
		T.expect(ActionFx.due(1, nil, 1.1)).toBe(true)
		T.expect(ActionFx.due(1, nil, 1 + ActionFx.LATE + 0.01)).toBe(false)
		T.expect(ActionFx.due(0, nil, 0)).toBe(true)
		T.expect(ActionFx.running(1, 2, 1)).toBe(true)
		T.expect(ActionFx.running(1, 2, 2)).toBe(false)
	end)
end)

T.describe("ActionFx elements and claims", function()
	T.it("takes the element and reach of the action's ability, else of the kind", function()
		local regular = (BipedStyles.get("wyvernRegular") :: any).abilities
		local breath = ActionFx.bound("wyvern", regular, "breath", "fireBreath")
		T.expect(breath.element).toBe("fire")
		T.expect(breath.radius).toBe(17)
		-- AnimLab plays the action without the attack: the kind's ability with this action
		T.expect(ActionFx.bound("wyvern", regular, "breath", nil).element).toBe("fire")
		-- the regular spit: the kind's own element
		T.expect(ActionFx.bound("wyvern", regular, "spit", nil).element).toBe("fire")
		local dragon = (BipedStyles.get("wyvern") :: any).abilities
		local frost = ActionFx.bound("vaelgrath", dragon, "breath", nil)
		T.expect(frost.element).toBe("ice")
		T.expect(frost.radius).toBe(22)
		local spirit = (BipedStyles.get("iceElemental") :: any).abilities
		T.expect(ActionFx.bound("iceElemental", spirit, "burst", nil).element).toBe("ice")
		T.expect(ActionFx.bound("iceElemental", spirit, "burst", nil).radius).toBe(13)
		local serpent = (RigidStyles.get("serpent") :: any).abilities
		T.expect(ActionFx.bound("frostWyrm", serpent, "breath", nil).element).toBe("ice")
		T.expect(ActionFx.bound("bogSerpent", serpent, "spit", nil).element).toBe("poison")
		local lizard = (RigidStyles.get("lizard") :: any).abilities
		T.expect(ActionFx.bound("salamander", lizard, "breath", nil).element).toBe("fire")
		T.expect(ActionFx.bound(nil, lizard, "breath", nil).element).toBeNil()
	end)

	T.it("lets every breathing kind and boss breathe and every frost nova erupt", function()
		local function check(id: string, ability: string, styleId: string?, kind: string)
			if not styleId or not styleOf(styleId) or not MotionFx.STYLES[styleId] then
				return -- not on a template monster style
			end
			local action = styleOf(styleId).abilities[ability]
			T.expect(action ~= nil).toBe(true)
			local list = MotionFx.get(styleId, action)
			T.expect(list ~= nil and #kindsOf(list :: { MotionFx.Fx }, kind) > 0).toBe(true)
			local bound = ActionFx.bound(id, styleOf(styleId).abilities, action, nil)
			T.expect(bound.element ~= nil).toBe(true)
		end
		local wants: { [string]: string } =
			{ fireBreath = "breath", frostBreath = "breath", frostNova = "nova", emberNova = "nova", boneNova = "nova" }
		for _, def in Monsters.list do
			local kind = def.ability and wants[def.ability]
			if kind then
				check(def.id, def.ability :: string, lookStyle(def.id, def.region), kind)
			end
		end
		for _, boss in Bosses.all do
			for _, attack in boss.attacks do
				local kind = wants[attack.id]
				if kind then
					check(boss.id, attack.id, lookStyle(boss.id, nil), kind)
				end
			end
		end
	end)

	T.it("gives the humanoids' casts the kind's element, else its school, and knows a magic kind", function()
		local caster = (BipedStyles.get("caster") :: any).abilities
		local imp = ActionFx.bound("fireImp", caster, "nova", nil)
		T.expect(imp.element).toBe("fire")
		T.expect(imp.radius).toBe(12)
		T.expect(ActionFx.bound("fireImp", caster, "spell", nil).element).toBe("fire")
		-- the witch's void pool has no element: the kind's poison
		T.expect(ActionFx.bound("marshWitch", caster, "pool", "voidPool").element).toBe("poison")
		local necro = ActionFx.bound("necromancer", caster, "nova", nil)
		T.expect(necro.element).toBe("shadow")
		T.expect(necro.ability).toBe("boneNova")
		T.expect(necro.magic).toBe(true)
		T.expect(ActionFx.bound("goblinShaman", caster, "spell", nil).element).toBe("nature")
		T.expect(ActionFx.bound("darkCultist", caster, "spellLeft", nil).element).toBe("shadow")
		-- the mummy's bone nova: the ability's school
		T.expect(ActionFx.bound("desertMummy", (BipedStyles.get("brute") :: any).abilities, "crush", nil).element)
			.toBe("shadow")
		local sword = (BipedStyles.get("humanoid1h") :: any).abilities
		local bandit = ActionFx.bound("bandit", sword, "crush", "crush")
		T.expect(bandit.element).toBeNil()
		T.expect(bandit.magic).toBe(false)
		local spawn = ActionFx.bound("dragonspawn", sword, "breath", nil)
		T.expect(spawn.element).toBe("fire")
		T.expect(spawn.radius).toBe(17)
		T.expect(ActionFx.bound("frozenKnight", sword, "cleave", "cleave").element).toBe("ice")
		T.expect(ActionFx.bound("forestWraith", caster, "nova", nil).element).toBe("ice")
	end)

	T.it("lets every caster's spell leave the staff or the hand at W and every humanoid cast release", function()
		for _, styleId in { "caster", "ghost" } do
			for _, name in { "spell", "spellLeft", "pool", "nova" } do
				local list = MotionFx.get(styleId, name) :: { MotionFx.Fx }
				T.expect(list ~= nil).toBe(true)
				T.expect(#kindsOf(list, "charge")).toBe(1)
				T.expect(#kindsOf(list, "bolt") + #kindsOf(list, "nova")).toBe(1)
			end
		end
		-- every humanoid kind's own ability (a nova, a pool, a breath) plays an action that releases something
		local casts = { emberNova = true, frostNova = true, boneNova = true, voidPool = true, fireBreath = true }
		for _, def in Monsters.list do
			local styleId = lookStyle(def.id, def.region)
			local style = styleId and BipedStyles.get(styleId)
			if style and def.ability and casts[def.ability] and MotionFx.STYLES[styleId :: string] then
				local action = style.abilities[def.ability]
				T.expect(action ~= nil).toBe(true)
				local _, release = ActionFx.claims(styleId :: string, style.abilities, def.ability)
				T.expect(release).toBe(true)
			end
		end
		-- a throw holds its rock until W; a heavy swing leaves a streak
		local held = kindsOf(MotionFx.get("humanoid1h", "throw") :: { MotionFx.Fx }, "held")[1]
		local throw = (BipedStyles.get("humanoid1h") :: any).actions.throw
		local _, t1 = ActionFx.window(throw, 0.74, held)
		T.expect(t1).toBeNear(0.74, 1e-9)
		T.expect(#kindsOf(MotionFx.get("humanoid1h", "heavy") :: { MotionFx.Fx }, "trail")).toBe(1)
	end)

	T.it("claims the gather and the release an attack's animation draws", function()
		local regular = (BipedStyles.get("wyvernRegular") :: any).abilities
		local gather, release = ActionFx.claims("wyvernRegular", regular, "fireBreath")
		T.expect(gather).toBe(true)
		T.expect(release).toBe(true)
		local bear = (QuadStyles.get("bear") :: any).abilities
		gather, release = ActionFx.claims("bear", bear, "slam")
		T.expect(gather).toBe(false)
		T.expect(release).toBe(true)
		local spirit = (BipedStyles.get("iceElemental") :: any).abilities
		gather, release = ActionFx.claims("iceElemental", spirit, "frostNova")
		T.expect(gather).toBe(true)
		T.expect(release).toBe(true)
		-- a boss pattern's gesture names the action itself
		gather = ActionFx.claims("wyvern", (BipedStyles.get("wyvern") :: any).abilities, "breath")
		T.expect(gather).toBe(true)
		gather, release = ActionFx.claims("bear", bear, nil)
		T.expect(gather or release).toBe(false)
		gather, release = ActionFx.claims("hare", {}, "bite")
		T.expect(gather or release).toBe(false)
		local sword = (BipedStyles.get("humanoid1h") :: any).abilities
		gather, release = ActionFx.claims("humanoid1h", sword, "fireBreath")
		T.expect(gather and release).toBe(true)
		-- a cleave's streak is neither: the generic glow and burst stay
		gather, release = ActionFx.claims("humanoid1h", sword, "cleave")
		T.expect(gather or release).toBe(false)
		gather, release = ActionFx.claims("caster", (BipedStyles.get("caster") :: any).abilities, "boneNova")
		T.expect(gather and release).toBe(true)
	end)
end)
