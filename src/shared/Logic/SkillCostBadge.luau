--!strict
-- Owner 2026-10-21 ("show the skill's cost in the left corner of the bar, mana blue, energy yellow"): the small number
-- in the top-left corner of a skill slot (Hud/SkillBar, Hud/MobileSkills). The cost is the one the server takes and
-- the tooltip shows (Skills.cost after rank, breakpoints, nodes, the item saving and Arcane Charges; a beam: the mana
-- of one tick), rounded up like the tooltip (the bar needs the full amount). Pure.

local SkillCostBadge = {}

-- The resources a badge is drawn for, with their colour (UI/Theme.Resource key).
SkillCostBadge.COLORS = table.freeze({
	mana = "Mana",
	energy = "Energy",
	hp = "Hp",
}) :: { [string]: string }

-- The badge text for `cost` of `resource` ("12", "1.5k", "24k"), nil when there is nothing to show.
function SkillCostBadge.label(cost: number?, resource: string?): string?
	if type(cost) ~= "number" or cost ~= cost or cost == math.huge or cost <= 0 then
		return nil
	end
	if type(resource) ~= "string" or SkillCostBadge.COLORS[resource] == nil then
		return nil
	end
	local n = math.ceil(cost - 1e-6)
	if n < 1000 then
		return tostring(math.max(1, n))
	elseif n < 10000 then
		local tenths = math.floor(n / 100) / 10
		return if tenths == math.floor(tenths) then `{tenths}k` else string.format("%.1fk", tenths)
	end
	return `{math.floor(n / 1000)}k`
end

-- Owner 2026-10-21 ("the cost badges are 12 x 12 px, too small: ~16-18 px, without covering the icon's centre, the
-- cooldown or the key"): the number stands on a dark plate about SCREEN_PX real pixels tall whatever the screen (the
-- UI scale shrinks a 1366 x 768 screen's HUD to 0.71: the old 15 px caption was 11 px there).
SkillCostBadge.SCREEN_PX = 17
SkillCostBadge.PAD = 4 -- the plate's room left and right of the number
SkillCostBadge.EDGE = 4 -- the plate's height over the text's
SkillCostBadge.INSET = 2 -- a bar slot: the plate's left edge from the slot's
-- A button of the touch arc: the plate's centre from the button's, in radii towards the attack button (a phone's
-- smaller buttons a little further out, off the picture).
SkillCostBadge.RIM = table.freeze({ tablet = 1.1, phone = 1.3 })

-- The text size of `sizes` (virtual pixels, UI/Theme.TextSize tokens) that shows closest to SCREEN_PX real pixels at
-- UI scale `scale`; a tie takes the bigger one.
function SkillCostBadge.textSize(scale: number, sizes: { number }): number
	local best, miss = sizes[1], math.huge
	for _, size in sizes do
		local d = math.abs(size * scale - SkillCostBadge.SCREEN_PX)
		if d < miss - 1e-9 or (d <= miss + 1e-9 and size > best) then
			best, miss = size, d
		end
	end
	return best
end

-- The plate's height for a text size.
function SkillCostBadge.plateHeight(textSize: number): number
	return textSize + SkillCostBadge.EDGE
end

-- A slot of the bar (Hud/SkillBar): the plate's top-left corner from the slot's. Half of it stands over the slot's
-- top edge, so it covers only the top strip of the picture: never its centre, the cooldown's seconds (centred) or the
-- key (bottom right).
function SkillCostBadge.barPlate(textSize: number): (number, number)
	return SkillCostBadge.INSET, -math.floor(SkillCostBadge.plateHeight(textSize) / 2)
end

-- How far the bar's plates stand over the slots' top edge (Hud/PoolLabel stands higher by this much).
function SkillCostBadge.overhang(textSize: number): number
	local _, y = SkillCostBadge.barPlate(textSize)
	return -y
end

-- A round button of the touch arc (Hud/MobileSkills) of `size` at `angle` degrees on the arc (0 right, 90 up): the
-- plate's centre from the button's centre, on its rim towards the attack button (`rim`: SkillCostBadge.RIM). The ring
-- between the arc and the attack button is free; the page and target buttons stand outside the arc, the neighbours
-- along it.
function SkillCostBadge.arcPlate(angle: number, size: number, rim: number): (number, number)
	local a = math.rad(angle)
	local r = size / 2 * rim
	return -math.cos(a) * r, math.sin(a) * r
end

return SkillCostBadge
