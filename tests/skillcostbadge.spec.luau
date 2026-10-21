--!strict
-- Owner 2026-10-21: the cost number in a skill slot's corner (Logic/SkillCostBadge).

local HudStack = require("../src/shared/Logic/HudStack")
local PhoneHud = require("../src/shared/Logic/PhoneHud")
local SkillCostBadge = require("../src/shared/Logic/SkillCostBadge")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local T = require("./Test")

T.describe("Skill cost badge", function()
	T.it("rounds a cost up like the tooltip", function()
		T.expect(SkillCostBadge.label(12, "mana")).toBe("12")
		T.expect(SkillCostBadge.label(12.2, "energy")).toBe("13")
		T.expect(SkillCostBadge.label(12.0000001, "mana")).toBe("12")
		T.expect(SkillCostBadge.label(0.4, "mana")).toBe("1")
	end)
	T.it("shortens big costs", function()
		T.expect(SkillCostBadge.label(999, "mana")).toBe("999")
		T.expect(SkillCostBadge.label(1000, "mana")).toBe("1k")
		T.expect(SkillCostBadge.label(1540, "mana")).toBe("1.5k")
		T.expect(SkillCostBadge.label(24400, "mana")).toBe("24k")
	end)
	T.it("draws nothing for a free skill or an unknown resource", function()
		T.expect(SkillCostBadge.label(0, "mana")).toBe(nil)
		T.expect(SkillCostBadge.label(nil, "mana")).toBe(nil)
		T.expect(SkillCostBadge.label(0 / 0, "mana")).toBe(nil)
		T.expect(SkillCostBadge.label(10, nil)).toBe(nil)
		T.expect(SkillCostBadge.label(10, "rage")).toBe(nil)
	end)
	T.it("has a colour for every resource a skill costs", function()
		for _, skill in SkillData.byId do
			if skill.resource then
				T.expect(SkillCostBadge.COLORS[skill.resource] ~= nil).toBe(true)
			end
		end
	end)
	T.it("follows the rank: a skill's badge is the cost Skills.cost gives at that rank", function()
		for _, skill in SkillData.byId do
			if skill.resource and skill.cost then
				local low = Skills.cost(skill, 1, 1, skill.class, nil)
				T.expect(SkillCostBadge.label(low, skill.resource))
					.toBe(if low > 0 then tostring(math.max(1, math.ceil(low - 1e-6))) else nil)
				return
			end
		end
	end)

	-- Studio review: "12 x 12 px, too small; ~16-18 px, not over the icon's centre, the cooldown or the key"
	-- UI/Theme.TextSize Small, Body, Large (the bar's sizes) and the bar slot (Hud: SLOT_SIZE).
	local SIZES = { 17, 20, 24 }
	local SLOT = 56
	-- the widest common number ("999", "1.5k") in text sizes, and the plate round it
	local function plateWidth(textSize: number): number
		return math.ceil(textSize * 1.8) + 2 * SkillCostBadge.PAD
	end

	T.it("shows the number about 16-18 real pixels tall on a PC screen", function()
		-- UI/Scale: 1366 x 768 (0.711), 1600 x 900 (0.833), 1920 x 1080 (1)
		T.expect(SkillCostBadge.textSize(1366 / 1920, SIZES)).toBe(24)
		T.expect(SkillCostBadge.textSize(1600 / 1920, SIZES)).toBe(20)
		T.expect(SkillCostBadge.textSize(1, SIZES)).toBe(17)
		for scale = 0.65, 1.0, 0.01 do
			local shown = SkillCostBadge.textSize(scale, SIZES) * scale
			if shown < 15.5 or shown > 18.5 then
				error(`UI scale {scale}: {shown} px`)
			end
		end
		-- the 0.6 floor (a small window) and big screens: never under Small
		T.expect(SkillCostBadge.textSize(0.6, SIZES)).toBe(24)
		T.expect(SkillCostBadge.textSize(1.5, SIZES)).toBe(17)
	end)

	T.it("a bar slot's plate stands half over the slot's top edge, clear of the seconds and the key", function()
		for _, size in SIZES do
			local x, y = SkillCostBadge.barPlate(size)
			local h = SkillCostBadge.plateHeight(size)
			T.expect(y < 0).toBe(true)
			T.expect(-y >= h / 2 - 1).toBe(true)
			local bottom = y + h
			-- the cooldown's seconds: Body (20) centred in the slot; the key: a 16 px plaque 2 px over the bottom
			T.expect(bottom <= SLOT / 2 - 20 / 2 - 2).toBe(true)
			T.expect(bottom <= SLOT - 2 - 16).toBe(true)
			-- inside the slot's width (the next slot stands 6 px away)
			T.expect(x >= 0).toBe(true)
			T.expect(x + plateWidth(size) <= SLOT).toBe(true)
			T.expect(SkillCostBadge.overhang(size)).toBe(-y)
		end
	end)

	-- The plates of a touch arc (`centres` of round buttons of `size`, at `angles`) against its buttons and `others`.
	local function arcClashes(
		centres: { { number } },
		angles: { number },
		size: number,
		rim: number,
		others: { [string]: { left: number, top: number, right: number, bottom: number } }
	): { string }
		local textSize = 17 -- Theme.TextSize.Small (Hud/MobileSkills)
		local w, h = plateWidth(textSize), SkillCostBadge.plateHeight(textSize)
		local plates = {}
		for i, c in centres do
			local dx, dy = SkillCostBadge.arcPlate(angles[i], size, rim)
			local cx, cy = c[1] + dx, c[2] + dy
			plates[i] = { left = cx - w / 2, top = cy - h / 2, right = cx + w / 2, bottom = cy + h / 2 }
		end
		local out = {}
		local function nearest(px: number, py: number, r: { left: number, top: number, right: number, bottom: number })
			local x, y = math.clamp(px, r.left, r.right), math.clamp(py, r.top, r.bottom)
			return math.sqrt((x - px) ^ 2 + (y - py) ^ 2)
		end
		for i, plate in plates do
			for j, c in centres do
				local d = nearest(c[1], c[2], plate)
				if j ~= i and d < size / 2 then
					table.insert(out, `plate {i} / button {j}`)
				elseif j == i and d < size * 0.2 then
					table.insert(out, `plate {i} near its centre ({d})`)
				end
			end
			for j = i + 1, #plates do
				if HudStack.overlaps(plate, plates[j]) then
					table.insert(out, `plate {i} / plate {j}`)
				end
			end
			for name, r in others do
				if HudStack.overlaps(plate, r) then
					table.insert(out, `plate {i} / {name}`)
				end
			end
		end
		return out
	end

	T.it("a touch arc's plates sit on the rims towards the attack button, clear of everything", function()
		-- a tablet (Logic/HudStack)
		local W, H = 1280, 800
		local centres = {}
		for i = 1, #HudStack.ARC.angles do
			local x, y = HudStack.skillCenter(i)
			centres[i] = { W + x, H + y }
		end
		local others = {}
		for name, r in HudStack.fixed(true, W, H) do
			if not string.match(name, "^skill") then
				others[name] = r
			end
		end
		local bad = arcClashes(centres, HudStack.ARC.angles, HudStack.ARC.size, SkillCostBadge.RIM.tablet, others)
		if #bad > 0 then
			error(`tablet: {table.concat(bad, ", ")}`)
		end
		-- the phones (Logic/PhoneHud)
		for _, d in PhoneHud.DEVICES do
			local w, h = PhoneHud.area(d)
			local phone = {}
			for i = 1, #PhoneHud.ANGLES do
				local x, y = PhoneHud.skillCenter(i)
				phone[i] = { w + x, h + y }
			end
			local near = {}
			for name, place in PhoneHud.PLACES do
				if not string.match(name, "^skill") and name ~= "stack" then
					near[name] = PhoneHud.rect(place, w, h)
				end
			end
			local clashes = arcClashes(phone, PhoneHud.ANGLES, PhoneHud.SKILL, SkillCostBadge.RIM.phone, near)
			if #clashes > 0 then
				error(`{d.name}: {table.concat(clashes, ", ")}`)
			end
		end
	end)
end)

return nil
