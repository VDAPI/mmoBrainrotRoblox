--!strict
-- S160 (owner 2026-10-21: "boss abilities are barely visible"): the cast bar's names, the warning banner, the vivid
-- rim colours against every kind of ground, the telegraph's visibility numbers and the timings (Logic/BossCast,
-- Logic/Telegraph, Config.Telegraph / BossCast).

local BossCast = require("../src/shared/Logic/BossCast")
local Bosses = require("../src/shared/Data/Bosses")
local Config = require("../src/shared/Config")
local Contrast = require("../src/shared/Logic/Contrast")
local HazardPatterns = require("../src/shared/Data/HazardPatterns")
local Hazards = require("../src/shared/Logic/Hazards")
local MapLooks = require("../src/shared/Data/MapLooks")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local T = require("./Test")
local Telegraph = require("../src/shared/Logic/Telegraph")
local fs = require("@lune/fs")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local CFG = Config.Telegraph

-- The first name key that exists in both languages (what the client shows), or nil.
local function shownName(bossId: string?, attackId: string?, patternId: string?): string?
	for _, key in BossCast.nameKeys(bossId, attackId, patternId) do
		if pl[key] and en[key] then
			return key
		end
	end
	return nil
end

-- Telegraph colours of CombatFxController (ELEMENT_COLORS, TELEGRAPH_COLOR) and the mechanics / lethal of Config.
local TELE_COLORS = { "#D64A3E", "#FF7A1A", "#7FD4FF", "#E8E25A", "#7ACB3A", CFG.lethalColor }
for _, hex in CFG.mechanicColors do
	table.insert(TELE_COLORS, hex)
end
for _, pattern in HazardPatterns.byId do
	table.insert(TELE_COLORS, pattern.color)
end

-- Ground the fights happen on: meadow grass, dark forest floor, dungeon and cave stone, crypt floor, lava rock, sand,
-- snow and ice.
local GROUNDS = {
	"#6FA046",
	"#4E7A34",
	"#2E3B22",
	"#3A3A40",
	"#2A2622",
	"#1C1A1E",
	"#3B2A22",
	"#D8C79A",
	"#EEF4FA",
	"#BFD9EC",
}

T.describe("Boss cast bar and banner (S160)", function()
	T.it("every boss attack has a name for its cast bar in both languages", function()
		for _, boss in Bosses.all do
			for _, attack in boss.attacks do
				local key = shownName(boss.id, attack.id, nil)
				T.expect({ boss.id, attack.id, key ~= nil }).toEqual({ boss.id, attack.id, true })
			end
		end
	end)

	T.it("every boss hazard pattern has a name (an ambient pattern sends its own id as the attack)", function()
		for id, pattern in HazardPatterns.byId do
			if not pattern.regular then
				T.expect({ id, shownName(nil, id, id) ~= nil }).toEqual({ id, true })
				T.expect({ id, shownName("grimrok", id, id) ~= nil }).toEqual({ id, true })
			end
		end
	end)

	T.it("every telegraphed monster ability (Elite / Elite II kits, the Invasion commander) has a name", function()
		for id in MonsterAbilities.byId do
			T.expect({ id, shownName(nil, id, nil) ~= nil }).toEqual({ id, true })
		end
	end)

	T.it("a boss attack's own name wins over a pattern's", function()
		local keys = BossCast.nameKeys("grimrok", "groundSplitter", "gr_fissure")
		T.expect(keys[1]).toBe("boss.grimrok.attack.groundSplitter")
		T.expect(keys[2]).toBe("hazard.gr_fissure.name")
	end)

	T.it("the banner warns of big attacks only, never of party mechanics or regular shots", function()
		T.expect(BossCast.banner({ mechanic = "avoid" })).toBe("boss.cast.avoid")
		T.expect(BossCast.banner({ lethal = true })).toBe("boss.cast.lethal")
		T.expect(BossCast.banner({ lethal = true, mechanic = "avoid" })).toBe("boss.cast.lethal")
		T.expect(BossCast.banner({ big = true })).toBe("boss.cast.dodge")
		T.expect(BossCast.banner({})).toBeNil()
		T.expect(BossCast.banner({ big = true, regular = true })).toBeNil()
		for _, m in { "split", "mark", "channel" } do
			T.expect(BossCast.banner({ mechanic = m })).toBeNil()
		end
		for _, key in { "boss.cast.avoid", "boss.cast.lethal", "boss.cast.dodge" } do
			T.expect({ key, pl[key] ~= nil and en[key] ~= nil }).toEqual({ key, true })
			T.expect({ key, string.find(pl[key], "{name}", 1, true) ~= nil }).toEqual({ key, true })
		end
	end)

	T.it("every big blow to dodge and every big pattern gets a banner", function()
		for _, boss in Bosses.all do
			for _, attack in boss.attacks do
				if attack.avoid then
					T.expect({ attack.id, BossCast.banner({ mechanic = "avoid" }) ~= nil }).toEqual({ attack.id, true })
				end
			end
		end
		for id, pattern in HazardPatterns.byId do
			if pattern.big then
				T.expect({ id, BossCast.banner({ big = pattern.big, regular = pattern.regular }) ~= nil }).toEqual({
					id,
					true,
				})
			end
		end
	end)

	T.it("one banner per gap: the areas of one attack do not stack banners", function()
		T.expect(BossCast.allowBanner(nil, 10)).toBe(true)
		T.expect(BossCast.allowBanner(10, 10.2)).toBe(false)
		T.expect(BossCast.allowBanner(10, 10 + Config.BossCast.bannerGap)).toBe(true)
		T.expect(Config.BossCast.bannerGap <= 2 and Config.BossCast.bannerSeconds >= 1.5).toBe(true)
	end)

	T.it("the cast bar lasts at least the shortest fair warning and matches longer windups", function()
		T.expect(BossCast.MIN_BAR).toBe(Hazards.MIN_WARN)
		T.expect(BossCast.barSeconds(0.2)).toBe(BossCast.MIN_BAR)
		T.expect(BossCast.barSeconds(nil)).toBe(BossCast.MIN_BAR)
		T.expect(BossCast.barSeconds(2.4)).toBe(2.4)
		-- every telegraphed boss attack warns at least that long, so its bar ends with the blow
		for _, boss in Bosses.all do
			for _, attack in boss.attacks do
				T.expect({ attack.id, attack.windup >= BossCast.MIN_BAR }).toEqual({ attack.id, true })
			end
		end
	end)
end)

T.describe("Boss telegraph visibility (S160)", function()
	T.it("the rim colour is vivid: saturated and bright, greys stay grey", function()
		for _, hex in TELE_COLORS do
			local v = BossCast.vivid(hex)
			local r, g, b = Contrast.rgb(v)
			T.expect({ hex, math.max(r, g, b) >= 0.94 * 255 }).toEqual({ hex, true })
		end
		-- dark crimson of a lethal blow turns into a bright red rim
		T.expect(Contrast.luminance(BossCast.vivid(CFG.lethalColor)) > Contrast.luminance(CFG.lethalColor) * 3)
			.toBe(true)
		local r, g, b = Contrast.rgb(BossCast.vivid("#808080"))
		T.expect(r == g and g == b).toBe(true)
	end)

	T.it("on every ground either the vivid rim or the dark under-rim stands out (contrast >= 3)", function()
		for _, hex in TELE_COLORS do
			local rim = BossCast.vivid(hex)
			for _, ground in GROUNDS do
				local best = math.max(Contrast.contrast(rim, ground), Contrast.contrast(CFG.underColor, ground))
				T.expect({ hex, ground, best >= 3 }).toEqual({ hex, ground, true })
			end
		end
	end)

	T.it("the telegraph layers are strong enough to read (owner: barely visible before)", function()
		T.expect(CFG.areaAlpha <= 0.7).toBe(true)
		T.expect(CFG.fillFrom <= 0.6 and CFG.fillTo <= 0.3 and CFG.fillTo < CFG.fillFrom).toBe(true)
		T.expect(CFG.rimWidth >= 0.6 and CFG.rimWidthAvoid >= 1.5 * CFG.rimWidth).toBe(true)
		T.expect(CFG.underRim >= 0.4 and CFG.underAlpha <= 0.3).toBe(true)
		T.expect(CFG.edgeThick >= 0.3 and CFG.lift >= 0.15).toBe(true)
		T.expect(CFG.flashSeconds >= 0.1).toBe(true)
		-- the pulse never makes the area vanish or go opaque
		for _, rim in { 0.1, 0.3, 0.55 } do
			for _, p in { 0, 0.5, 1 } do
				local a = Telegraph.areaAlpha(CFG.areaAlpha, CFG.areaPulse, rim, p)
				T.expect(a <= CFG.areaAlpha and a >= 0.35).toBe(true)
			end
		end
	end)

	T.it("a big area gets a rim in proportion to its size", function()
		T.expect(Telegraph.rimFor(CFG.rimWidth, 4, CFG.rimShare)).toBe(CFG.rimWidth)
		T.expect(Telegraph.rimFor(CFG.rimWidth, 30, CFG.rimShare)).toBeNear(30 * CFG.rimShare, 1e-9)
		-- never more than a tenth of the radius (the area stays readable)
		T.expect(CFG.rimShare <= 0.1).toBe(true)
	end)

	T.it("the light round the rim runs on and speeds up towards the blow, then holds", function()
		local w = 2
		local last = -1
		local lastStep = 0
		for i = 0, 20 do
			local t = w * i / 20
			local turns = Telegraph.chase(t, w, CFG.chaseSpeed)
			T.expect(turns > last).toBe(true)
			if i > 0 then
				T.expect(turns - last >= lastStep - 1e-9).toBe(true)
				lastStep = turns - last
			end
			last = turns
		end
		T.expect(Telegraph.chase(w + 1, w, CFG.chaseSpeed)).toBeNear(last, 1e-9)
		T.expect(Telegraph.chase(w, w, CFG.chaseSpeed)).toBeNear(CFG.chaseSpeed * 1.5 * w, 1e-9)
	end)
end)

-- Studio review 2026-10-21 (Hrimvald's stomp ring "white dashes" weak on snow, Vaelgrath's mark pale pink on ice,
-- Azgor's meteor orange on lava): the telegraph's colours follow the ground under it (Logic/BossCast.onGround,
-- Vfx/Library.groundColor in GroundTelegraph and HazardFx).
local G = CFG.ground
-- every terrain colour of the maps (Data/MapLooks) and the grounds above
local ALL_GROUNDS = table.clone(GROUNDS)
for _, hex in MapLooks.TERRAIN_COLORS do
	table.insert(ALL_GROUNDS, hex)
end

local function hue(hex: string): (number, number)
	local r, g, b = Contrast.rgb(hex)
	local hi, lo = math.max(r, g, b), math.min(r, g, b)
	local d = hi - lo
	if d == 0 then
		return 0, 0
	end
	local h
	if hi == r then
		h = ((g - b) / d) % 6
	elseif hi == g then
		h = (b - r) / d + 2
	else
		h = (r - g) / d + 4
	end
	return h / 6, d / hi
end

local function hueGap(a: string, b: string): number
	local d = math.abs(hue(a) - hue(b)) % 1
	return math.min(d, 1 - d)
end

T.describe("Telegraph colours on their ground (studio review 2026-10-21)", function()
	T.it("on a light ground (snow, ice, sand) the rim itself stands out and keeps its hue", function()
		local seen = 0
		for _, hex in TELE_COLORS do
			for _, ground in ALL_GROUNDS do
				if Contrast.luminance(ground) >= G.light then
					local style = BossCast.onGround(hex, ground)
					T.expect({ hex, ground, Contrast.contrast(style.rim, ground) >= G.rimMin }).toEqual({
						hex,
						ground,
						true,
					})
					T.expect({ hex, ground, hueGap(style.rim, BossCast.vivid(hex)) <= 0.02 }).toEqual({
						hex,
						ground,
						true,
					})
					seen += 1
				end
			end
		end
		T.expect(seen > 40).toBe(true)
	end)

	T.it("on every ground the rim or the dark under-rim stands out, and a deep or white-hot rim gains", function()
		for _, hex in TELE_COLORS do
			local vivid = BossCast.vivid(hex)
			for _, ground in ALL_GROUNDS do
				local style = BossCast.onGround(hex, ground)
				local best = math.max(Contrast.contrast(style.rim, ground), Contrast.contrast(style.under, ground))
				T.expect({ hex, ground, best >= 3 }).toEqual({ hex, ground, true })
				T.expect({ hex, ground, style.underScale >= 1 }).toEqual({ hex, ground, true })
				if style.kind == "plain" then
					T.expect(style.rim).toBe(vivid)
				else
					-- never weaker than the vivid rim, and the dark under-rim widens with it
					local gain = Contrast.contrast(style.rim, ground) > Contrast.contrast(vivid, ground)
					T.expect({ hex, ground, gain, style.underScale > 1 }).toEqual({ hex, ground, true, true })
				end
			end
		end
		-- without a ground (nothing under the area) the S160 rim stays
		T.expect(BossCast.onGround("#FF7A1A", nil).rim).toBe(BossCast.vivid("#FF7A1A"))
		-- on dark rock the vivid rim already stands out: unchanged
		T.expect(BossCast.onGround("#FF7A1A", MapLooks.TERRAIN_COLORS.Basalt).kind).toBe("plain")
	end)

	T.it("Hrimvald's stomp ring and ice spikes, Vaelgrath's mark: deep on snow and ice", function()
		local T_ = MapLooks.TERRAIN_COLORS
		local cases = {
			{ (HazardPatterns.get("hv_stompRing") :: any).color, T_.Snow },
			{ (HazardPatterns.get("hv_stompRing") :: any).color, T_.Ice },
			{ (HazardPatterns.get("hv_spikeWave") :: any).color, T_.Snow },
			{ (HazardPatterns.get("hv_spikeWave") :: any).color, T_.Glacier },
			{ CFG.mechanicColors.mark, T_.Ice },
			{ CFG.mechanicColors.mark, T_.Snow },
		}
		for _, case in cases do
			local style = BossCast.onGround(case[1], case[2])
			T.expect({ case[1], case[2], style.kind }).toEqual({ case[1], case[2], "deep" })
			T.expect(Contrast.contrast(style.rim, case[2]) >= G.rimMin + 0.4).toBe(true)
			T.expect(Contrast.contrast(style.front, case[2]) >= G.rimMin).toBe(true)
		end
		-- the ring's glowing band was the pattern's colour whitened: pale dashes on white (owner's screenshot)
		local before = Contrast.mix(BossCast.vivid((HazardPatterns.get("hv_stompRing") :: any).color), "#FFFFFF", 0.2)
		T.expect(Contrast.contrast(before, T_.Snow) < 2).toBe(true)
	end)

	T.it("Azgor's fire on lava turns white-hot over a wider dark under-rim", function()
		local lava = MapLooks.TERRAIN_COLORS.CrackedLava
		for _, id in { "az_meteor", "az_fireballs", "az_flameWall", "az_magma" } do
			local color = (HazardPatterns.get(id) :: any).color
			local style = BossCast.onGround(color, lava)
			T.expect({ id, style.kind }).toEqual({ id, "hot" })
			T.expect({ id, Contrast.contrast(style.rim, lava) >= G.rimMin }).toEqual({ id, true })
			T.expect(Contrast.luminance(style.rim) > Contrast.luminance(BossCast.vivid(color))).toBe(true)
			T.expect(style.underScale).toBe(G.underHot)
		end
	end)

	T.it("the client draws them on the ground it finds (GroundTelegraph, HazardFx)", function()
		local tele = fs.readFile("src/client/Vfx/GroundTelegraph.luau")
		T.expect(string.find(tele, "BossCast.onGround(", 1, true) ~= nil).toBe(true)
		T.expect(string.find(tele, "Library.groundColor(spec.area.Position)", 1, true) ~= nil).toBe(true)
		local fx = fs.readFile("src/client/Vfx/HazardFx.luau")
		T.expect(string.find(fx, "BossCast.onGround(pattern.color, Library.groundColor(at))", 1, true) ~= nil)
			.toBe(true)
		-- the stomp ring's blocks and band, the lanes, the walls and the ice spikes take the ground's colour
		local _, uses = string.gsub(fx, "live%.mark", "")
		T.expect(uses >= 6).toBe(true)
		T.expect(string.find(fx, "if live.deep then live.mark else", 1, true) ~= nil).toBe(true)
		local lib = fs.readFile("src/client/Vfx/Library.luau")
		T.expect(string.find(lib, "GetMaterialColor(hit.Material)", 1, true) ~= nil).toBe(true)
	end)
end)

return nil
