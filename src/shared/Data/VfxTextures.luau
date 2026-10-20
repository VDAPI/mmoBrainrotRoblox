--!strict
-- Effect textures (S112, DESIGN-16 §4): white-on-transparent PNGs drawn by tools/vfx/make_textures.py into art/vfx/
-- (manifest art/vfx/manifest.json) and uploaded as images. `id` is filled in by hand after the upload
-- (docs/ANIMACJE.md, "Tekstury efektów"); an empty id keeps the old look (neon parts, the default particle), so the
-- game works before and after the upload. The client tints every texture with the effect's colour (client/Vfx/Textures
-- turns these names into Enum values; nothing here touches the Roblox API).
--   kind: particle (ParticleEmitter), beam (glowing layers: rays and cutting arcs as a Beam, round circles on the
--     ground as an unlit image on a flat part, Vfx/Library), trail (Trail), decal (Decal: dark marks on the ground,
--     they do not glow)
--   grid / frames / mode: a flipbook (particles only): 2x2 = 4, 4x4 = 16, 8x8 = 64 frames; oneShot plays the whole
--     sequence over a particle's life, loop at 16-24 frames per second
--   emission: default LightEmission (0 = lit by the scene like smoke and dust, 1 = glows)
--   wrap: the texture tiles along U (beams / trails, TextureMode Wrap); otherwise Stretch

export type Kind = "particle" | "beam" | "trail" | "decal"
export type Grid = "2x2" | "4x4" | "8x8"
export type Mode = "loop" | "oneShot" | "pingPong" | "random"

export type Texture = {
	id: string, -- "rbxassetid://<digits>" or "" (not uploaded yet)
	file: string, -- file name in art/vfx/
	w: number,
	h: number,
	kind: Kind,
	grid: Grid?, -- flipbook layout (particles only)
	frames: number?, -- frames of the flipbook (4 for 2x2, 16 for 4x4, 64 for 8x8)
	mode: Mode?, -- flipbook playback
	emission: number?, -- default LightEmission (0..1)
	wrap: boolean?, -- beams / trails: the texture tiles along U
}

local function t(def: Texture): Texture
	return table.freeze(def)
end

-- Uploaded 2026-10-14 through the Studio MCP (upload_image, the game owner's account VDaPii).
local list: { [string]: Texture } = {
	glow = t({
		id = "rbxassetid://126255806367956",
		file = "glow.png",
		w = 256,
		h = 256,
		kind = "particle",
		emission = 1,
	}),
	spark = t({
		id = "rbxassetid://106535697977855",
		file = "spark.png",
		w = 128,
		h = 128,
		kind = "particle",
		emission = 1,
	}),
	star = t({
		id = "rbxassetid://100872117511575",
		file = "star.png",
		w = 256,
		h = 256,
		kind = "particle",
		emission = 1,
	}),
	smoke = t({
		id = "rbxassetid://104846842992360",
		file = "smoke.png",
		w = 1024,
		h = 1024,
		kind = "particle",
		grid = "4x4",
		frames = 16,
		mode = "oneShot",
		emission = 0,
	}),
	fire = t({
		id = "rbxassetid://90857957796097",
		file = "fire.png",
		w = 1024,
		h = 1024,
		kind = "particle",
		grid = "4x4",
		frames = 16,
		mode = "loop",
		emission = 1,
	}),
	dust = t({
		id = "rbxassetid://111438083809910",
		file = "dust.png",
		w = 256,
		h = 256,
		kind = "particle",
		emission = 0,
	}),
	slashWide = t({
		id = "rbxassetid://122783745384680",
		file = "slash_wide.png",
		w = 512,
		h = 512,
		kind = "beam",
		emission = 1,
	}),
	slashNarrow = t({
		id = "rbxassetid://98048537515516",
		file = "slash_narrow.png",
		w = 512,
		h = 512,
		kind = "beam",
		emission = 1,
	}),
	ring = t({ id = "rbxassetid://74139774436754", file = "ring.png", w = 512, h = 512, kind = "beam", emission = 1 }),
	cracks = t({ id = "rbxassetid://112662325811211", file = "cracks.png", w = 512, h = 512, kind = "decal" }),
	runeWarrior = t({
		id = "rbxassetid://71343857983408",
		file = "rune_warrior.png",
		w = 512,
		h = 512,
		kind = "beam",
		emission = 1,
	}),
	runeHunter = t({
		id = "rbxassetid://106684683280596",
		file = "rune_hunter.png",
		w = 512,
		h = 512,
		kind = "beam",
		emission = 1,
	}),
	runeMage = t({
		id = "rbxassetid://123600175606558",
		file = "rune_mage.png",
		w = 512,
		h = 512,
		kind = "beam",
		emission = 1,
	}),
	runeCleric = t({
		id = "rbxassetid://113765063812082",
		file = "rune_cleric.png",
		w = 512,
		h = 512,
		kind = "beam",
		emission = 1,
	}),
	magicCircle = t({
		id = "rbxassetid://73817466629269",
		file = "magic_circle.png",
		w = 1024,
		h = 1024,
		kind = "beam",
		emission = 1,
	}),
	beamLightning = t({
		id = "rbxassetid://110361403160932",
		file = "beam_lightning.png",
		w = 256,
		h = 128,
		kind = "beam",
		emission = 1,
		wrap = true,
	}),
	beamHoly = t({
		id = "rbxassetid://83590719396089",
		file = "beam_holy.png",
		w = 256,
		h = 128,
		kind = "beam",
		emission = 1,
		wrap = true,
	}),
	beamArcane = t({
		id = "rbxassetid://127916963244423",
		file = "beam_arcane.png",
		w = 256,
		h = 128,
		kind = "beam",
		emission = 1,
		wrap = true,
	}),
	beamPoison = t({
		id = "rbxassetid://107022488674502",
		file = "beam_poison.png",
		w = 256,
		h = 128,
		kind = "beam",
		emission = 1,
		wrap = true,
	}),
	trailSoft = t({
		id = "rbxassetid://114686207787488",
		file = "trail_soft.png",
		w = 256,
		h = 64,
		kind = "trail",
		emission = 1,
	}),
	trailStreak = t({
		id = "rbxassetid://72057240840617",
		file = "trail_streak.png",
		w = 256,
		h = 64,
		kind = "trail",
		emission = 1,
	}),
	iceShard = t({
		id = "rbxassetid://98123194284901",
		file = "ice_shard.png",
		w = 256,
		h = 256,
		kind = "particle",
		emission = 0.6,
	}),
	poisonBubble = t({
		id = "rbxassetid://99590955740039",
		file = "poison_bubble.png",
		w = 1024,
		h = 1024,
		kind = "particle",
		grid = "4x4",
		frames = 16,
		mode = "oneShot",
		emission = 0.5,
	}),
	feather = t({
		id = "rbxassetid://116416891490358",
		file = "feather.png",
		w = 256,
		h = 256,
		kind = "particle",
		emission = 0,
	}),
	darkSpark = t({
		id = "rbxassetid://123356645047331",
		file = "dark_spark.png",
		w = 128,
		h = 128,
		kind = "particle",
		emission = 0,
	}),
	-- W05-W07 (class pass), uploaded 2026-10-20 through the Studio MCP
	slashBold = t({
		id = "rbxassetid://82973712784370",
		file = "slash_bold.png",
		w = 512,
		h = 512,
		kind = "beam",
		emission = 1,
	}),
	slashBoldNarrow = t({
		id = "rbxassetid://140000604187212",
		file = "slash_bold_narrow.png",
		w = 512,
		h = 512,
		kind = "beam",
		emission = 1,
	}),
	debris = t({
		id = "rbxassetid://131234273132557",
		file = "debris.png",
		w = 1024,
		h = 1024,
		kind = "particle",
		grid = "4x4",
		frames = 16,
		mode = "random",
		emission = 0,
	}),
	dustRing = t({
		id = "rbxassetid://126691594484092",
		file = "dust_ring.png",
		w = 512,
		h = 512,
		kind = "beam",
		emission = 0,
	}),
	hitStar = t({
		id = "rbxassetid://74601522337603",
		file = "hit_star.png",
		w = 256,
		h = 256,
		kind = "particle",
		emission = 1,
	}),
	rays = t({
		id = "rbxassetid://80487195939560",
		file = "rays.png",
		w = 512,
		h = 512,
		kind = "particle",
		emission = 1,
	}),
	swirl = t({
		id = "rbxassetid://139318164153393",
		file = "swirl.png",
		w = 512,
		h = 512,
		kind = "beam",
		emission = 1,
	}),
	leaf = t({
		id = "rbxassetid://93728815922981",
		file = "leaf.png",
		w = 1024,
		h = 1024,
		kind = "particle",
		grid = "2x2",
		frames = 4,
		mode = "random",
		emission = 0,
	}),
}

-- Keys in the generator's order (tests compare them with the manifest).
local ORDER = {
	"glow",
	"spark",
	"star",
	"smoke",
	"fire",
	"dust",
	"slashWide",
	"slashNarrow",
	"ring",
	"cracks",
	"runeWarrior",
	"runeHunter",
	"runeMage",
	"runeCleric",
	"magicCircle",
	"beamLightning",
	"beamHoly",
	"beamArcane",
	"beamPoison",
	"trailSoft",
	"trailStreak",
	"iceShard",
	"poisonBubble",
	"feather",
	"darkSpark",
	"slashBold",
	"slashBoldNarrow",
	"debris",
	"dustRing",
	"hitStar",
	"rays",
	"swirl",
	"leaf",
}

-- Rune circle of a class (Classes ids), magicCircle for anything else.
local RUNE_OF_CLASS: { [string]: string } = {
	Warrior = "runeWarrior",
	Hunter = "runeHunter",
	Mage = "runeMage",
	Cleric = "runeCleric",
}

-- The uploaded id of `key` in `from` (default: the list), nil while empty or unknown (callers keep the old look).
local function idOf(key: string, from: { [string]: Texture }?): string?
	local entry = (from or list)[key]
	return if entry and entry.id ~= "" then entry.id else nil
end

return table.freeze({
	list = table.freeze(list),
	ORDER = table.freeze(ORDER),
	RUNE_OF_CLASS = table.freeze(RUNE_OF_CLASS),
	get = function(key: string): Texture?
		return list[key]
	end,
	idOf = idOf,
	-- The rune circle key of a class, magicCircle when it has none.
	runeOf = function(class: string?): string
		return if class and RUNE_OF_CLASS[class] then RUNE_OF_CLASS[class] else "magicCircle"
	end,
})
