--!strict
-- Template animation (owner 2026-10-26: "wyvern ... bierze wdech nie wypuszcza ognia", "iceElemental burst ... na
-- koniec lodowe kolce"): the effects a keyed action of a template style releases, so every motion that lets something
-- go shows it, from the right bone at the right frame, in the game and in /animlab alike (client/Vfx/MotionFx draws
-- them, Logic/ActionFx times them). Per motion style (Data/MonsterAssets `motion`) and action name, a list of effects:
-- * `kind`: the piece (KINDS: a stream runs from `from` to `to` and follows its anchor every frame, the rest fire once
--   at `from`);
-- * `at`: the anchor on the rig (ANCHORS), resolved by client/Vfx/MotionFx per family;
-- * `from` / `to`: places on the action's timeline (Logic/MotionTimeline): "W" is the server's hit (the strike's end),
--   "A0.35" 35 % into the anticipation, "F0.85" 85 % into the follow-through, "R1" the end of the recovery;
-- * `size`: x the monster's size (its drawn height over a man's); `element`: a fixed element (else the action's
--   ability's, else the kind's own: Logic/ActionFx.bound).
-- HIT: the puff a hit knocks off a kind (feathers, splinters, ice chips; never blood).
-- The server's telegraph and its blow ring stay (Controllers/CombatFxController); a release piece of an action replaces
-- only the generic burst at the caster (KINDS `release`) and a gather piece the generic glow on its body (`gather`).
-- Data only (Lune: tests/actionfx.spec.luau checks every style, action and anchor exists and the timing rules).

export type Mark = { seg: string, u: number }
export type Fx = {
	kind: string,
	at: string,
	from: Mark,
	to: Mark?,
	size: number?,
	element: string?,
}
export type Kind = {
	stream: boolean?, -- runs from `from` to `to`, following its anchor
	gather: boolean?, -- a build-up before the release (the generic charge glow on the caster is left out)
	release: boolean?, -- the release itself (the generic burst at the caster's feet is left out)
}

local MotionFx = {}

-- The pieces (client/Vfx/MotionFx draws each).
MotionFx.KINDS = table.freeze({
	breath = { stream = true, release = true }, -- a stream of flame / frost / venom from the mouth along the head
	charge = { stream = true, gather = true }, -- the element gathering in the throat or the hand, a light growing
	arc = { stream = true, gather = true }, -- crackling arcs between the wing tips
	smolder = { stream = true }, -- smoke trickling from the mouth after a fire breath
	spit = { release = true }, -- a puff of the element from the mouth (a spit, a squirt of venom)
	bolt = { release = true }, -- a flash in the casting hand
	flare = { release = true }, -- a flash of lightning between the wing tips
	nova = { release = true }, -- ice shards flung out of the body and ice spikes erupting from the ground in a ring
	shatter = {}, -- the body bursting into ice shards (a death)
	slam = { release = true }, -- a blow into the ground: rock chips, a dust ring, cracks
	dust = {}, -- a dust puff on the ground (a landing, a fall, a wing beat)
	screech = { release = true }, -- rings of force running out of the mouth (a wail, a roar)
	wisps = {}, -- pale spirit wisps
	feathers = {}, -- loose feathers drifting down
	splinters = {}, -- wood chips and bark
	leaves = {}, -- leaves shaken off and fluttering down
	snow = {}, -- a puff of snow and ice chips
} :: { [string]: Kind })

-- The anchors (client/Vfx/MotionFx resolves each per family; a missing bone falls back to the body).
MotionFx.ANCHORS = table.freeze({
	mouth = true, -- the jaw / beak / the front of the mesh at the release height (Data/MonsterRelease)
	head = true,
	chest = true,
	handR = true,
	handL = true,
	wingL = true, -- a flyer's wing tip (the wyvern's long finger)
	wingR = true,
	wings = true, -- between the wing tips
	feet = true, -- the ground under the body
	front = true, -- the ground under the front feet
	body = true, -- the middle of the body
	top = true, -- the top of the body (a tree's crown)
	tail = true, -- a scorpion's sting over its back
	trunk = true, -- the tip of a mammoth's trunk
} :: { [string]: boolean })

local SEGMENTS: { [string]: boolean } = { A = true, S = true, F = true, R = true }

local function mark(text: string): Mark
	if text == "W" then
		return table.freeze({ seg = "S", u = 1 })
	end
	local seg, u = string.match(text, "^(%u)([%d%.]+)$")
	local share = tonumber(u)
	assert(seg and SEGMENTS[seg] and share and share >= 0 and share <= 1, `MotionFx: bad mark {text}`)
	return table.freeze({ seg = seg, u = share })
end

local function fx(kind: string, at: string, from: string, to: string?, opts: { size: number?, element: string? }?): Fx
	local o: { size: number?, element: string? } = opts or {}
	return table.freeze({
		kind = kind,
		at = at,
		from = mark(from),
		to = if to then mark(to) else nil,
		size = o.size,
		element = o.element,
	})
end

---------------------------------------------------------------- dragons (Data/BipedStyles)

-- Vaelgrath and every wyvern-styled boss: the breath (a stream along the head's sweep, its ability's element), the stomp,
-- the wing beat's dust, the roar, the crash of the death.
local WYVERN: { [string]: { Fx } } = {
	breath = {
		fx("charge", "mouth", "A0.35", "W"),
		fx("breath", "mouth", "W", "F0.85"),
		fx("smolder", "mouth", "F0.85", "R0.8"),
	},
	stomp = { fx("slam", "feet", "W", nil, { size = 1.2 }) },
	buffet = { fx("dust", "feet", "W", nil, { size = 1.6 }) },
	tail = { fx("dust", "feet", "F0.3", nil, { size = 0.8 }) },
	roar = { fx("screech", "mouth", "W", nil, { size = 1.2 }) },
	spawnDragon = { fx("dust", "feet", "W", nil, { size = 1.2 }) },
	deathDragon = { fx("dust", "body", "F1", nil, { size = 1.8 }) },
}

-- The regular wyvern: the same plus its fire spit (the basic shot) and the pounce's landing.
local WYVERN_REGULAR: { [string]: { Fx } } = table.clone(WYVERN)
WYVERN_REGULAR.spit = {
	fx("charge", "mouth", "A0.5", "W", { size = 0.6 }),
	fx("spit", "mouth", "W"),
}
WYVERN_REGULAR.pounce = { fx("dust", "feet", "W") }

---------------------------------------------------------------- spirits (Data/BipedStyles SPIRIT_ACTIONS)

-- The specter: a cold bolt from the hand, the wail's rings, wisps bursting and rising.
local SPECTER: { [string]: { Fx } } = {
	bolt = {
		fx("charge", "handR", "A0.3", "W", { size = 0.5 }),
		fx("bolt", "handR", "W"),
	},
	wail = { fx("screech", "mouth", "W"), fx("wisps", "chest", "W", nil, { size = 0.8 }) },
	aggro = { fx("wisps", "chest", "W", nil, { size = 0.6 }) },
	burst = { fx("wisps", "chest", "W", nil, { size = 1.4 }), fx("screech", "chest", "W", nil, { size = 0.8 }) },
	pool = { fx("wisps", "handR", "W") },
	spawnSpirit = { fx("wisps", "chest", "W", nil, { size = 1.2 }) },
	deathRise = { fx("wisps", "chest", "F0.3", nil, { size = 1.5 }) },
}

-- The ice elemental: the frost nova (owner: ice spikes at the end of the burst), the shatter of its death, a frost bolt.
local ICE_ELEMENTAL: { [string]: { Fx } } = {
	bolt = {
		fx("charge", "handR", "A0.3", "W", { size = 0.5, element = "ice" }),
		fx("bolt", "handR", "W", nil, { element = "ice" }),
	},
	wail = { fx("screech", "mouth", "W", nil, { element = "ice" }) },
	burst = {
		fx("charge", "chest", "A0.4", "W", { element = "ice" }),
		fx("nova", "chest", "W", nil, { element = "ice" }),
	},
	pool = { fx("snow", "handR", "W") },
	spawnSpirit = { fx("snow", "feet", "W") },
	deathShatter = { fx("shatter", "chest", "W", nil, { element = "ice" }) },
}

---------------------------------------------------------------- heavy quadrupeds (Data/QuadStyles)

local CANINE: { [string]: { Fx } } = {
	leap = { fx("dust", "feet", "W", nil, { size = 0.7 }) },
	pounce = { fx("dust", "feet", "W", nil, { size = 0.7 }) },
	rear = { fx("slam", "front", "W", nil, { size = 0.6 }) },
	deathL = { fx("dust", "body", "F1", nil, { size = 0.7 }) },
	deathR = { fx("dust", "body", "F1", nil, { size = 0.7 }) },
}

local BEAR: { [string]: { Fx } } = {
	slam = { fx("slam", "front", "W") },
	crush = { fx("slam", "front", "W", nil, { size = 1.3 }) },
	bodyslam = { fx("dust", "feet", "W", nil, { size = 1.2 }) },
	hurl = { fx("dust", "front", "W", nil, { size = 0.7 }) },
	deathL = { fx("dust", "body", "F1", nil, { size = 1.2 }) },
	deathR = { fx("dust", "body", "F1", nil, { size = 1.2 }) },
}

local BOAR: { [string]: { Fx } } = {
	stomp = { fx("slam", "front", "W", nil, { size = 0.9 }) },
	charge = { fx("dust", "feet", "S0.5", nil, { size = 0.8 }), fx("dust", "front", "W") },
	leap = { fx("dust", "feet", "W", nil, { size = 0.8 }) },
	rake = { fx("dust", "front", "W", nil, { size = 0.6 }) },
	root = { fx("dust", "mouth", "W", nil, { size = 0.5 }) },
	snort = { fx("dust", "mouth", "W", nil, { size = 0.4 }) },
	deathL = { fx("dust", "body", "F1") },
	deathR = { fx("dust", "body", "F1") },
}

local MAMMOTH: { [string]: { Fx } } = {
	stomp = { fx("slam", "front", "W", nil, { size = 1.2 }), fx("snow", "front", "W") },
	crush = { fx("slam", "front", "W", nil, { size = 1.5 }), fx("snow", "front", "W", nil, { size = 1.3 }) },
	lunge = { fx("dust", "feet", "W", nil, { size = 1.3 }) },
	fling = { fx("snow", "trunk", "W", nil, { size = 0.8 }) },
	trumpet = { fx("screech", "trunk", "W") },
	dust = { fx("dust", "trunk", "F0.4", nil, { size = 0.6 }) },
	deathL = { fx("dust", "body", "F1", nil, { size = 1.6 }), fx("snow", "body", "F1", nil, { size = 1.2 }) },
	deathR = { fx("dust", "body", "F1", nil, { size = 1.6 }), fx("snow", "body", "F1", nil, { size = 1.2 }) },
}

---------------------------------------------------------------- rigid kinds (Data/RigidStyles)

-- Venom: a spit of the kind's poison from the mouth (the regular shot's puff, the pool's bigger squirt).
local SPIDER: { [string]: { Fx } } = {
	spit = { fx("spit", "mouth", "W", nil, { size = 0.7, element = "poison" }) },
	pool = { fx("spit", "mouth", "W", nil, { element = "poison" }) },
	crush = { fx("dust", "front", "W", nil, { size = 0.6 }) },
	pounce = { fx("dust", "feet", "W", nil, { size = 0.6 }) },
	deathFlip = { fx("dust", "body", "F1", nil, { size = 0.6 }) },
	deathCurl = { fx("dust", "body", "F0.8", nil, { size = 0.6 }) },
}

local SCORPION: { [string]: { Fx } } = {
	spit = { fx("spit", "mouth", "W", nil, { size = 0.7, element = "poison" }) },
	pool = { fx("spit", "tail", "W", nil, { element = "poison" }) },
	crush = { fx("dust", "front", "W", nil, { size = 0.6 }) },
	pounce = { fx("dust", "feet", "W", nil, { size = 0.6 }) },
	deathFlip = { fx("dust", "body", "F1", nil, { size = 0.6 }) },
	deathCurl = { fx("dust", "body", "F0.8", nil, { size = 0.6 }) },
}

-- The salamander's fire breath, the basilisk's venom.
local LIZARD: { [string]: { Fx } } = {
	breath = {
		fx("charge", "mouth", "A0.4", "W", { size = 0.7 }),
		fx("breath", "mouth", "W", "F0.8", { size = 0.8 }),
		fx("smolder", "mouth", "F0.8", "R1", { size = 0.7 }),
	},
	spit = { fx("spit", "mouth", "W") },
	spitShot = { fx("spit", "mouth", "W", nil, { size = 0.7 }) },
	crush = { fx("dust", "front", "W", nil, { size = 0.6 }) },
	pounce = { fx("dust", "feet", "W", nil, { size = 0.6 }) },
	deathFlip = { fx("dust", "body", "F1", nil, { size = 0.6 }) },
	deathSide = { fx("dust", "body", "F1", nil, { size = 0.6 }) },
}

-- The frost wyrm's frost breath, the bog serpent's venom.
local SERPENT: { [string]: { Fx } } = {
	breath = {
		fx("charge", "mouth", "A0.4", "W", { size = 0.8 }),
		fx("breath", "mouth", "W", "F0.8"),
	},
	spit = { fx("spit", "mouth", "W") },
	spitShot = { fx("spit", "mouth", "W", nil, { size = 0.7 }) },
	crush = { fx("dust", "front", "W", nil, { size = 0.7 }) },
	pounce = { fx("dust", "feet", "W", nil, { size = 0.7 }) },
	deathSink = { fx("dust", "body", "F0.5", nil, { size = 0.8 }) },
	deathWrithe = { fx("dust", "body", "F0.6", nil, { size = 0.8 }) },
}

local TOAD: { [string]: { Fx } } = {
	spit = { fx("spit", "mouth", "W", nil, { element = "poison" }) },
	spitShot = { fx("spit", "mouth", "W", nil, { size = 0.7, element = "poison" }) },
	squash = { fx("dust", "feet", "F0.5", nil, { size = 0.5 }) },
	crush = { fx("dust", "front", "W", nil, { size = 0.6 }) },
	pounce = { fx("dust", "feet", "W", nil, { size = 0.6 }) },
	deathFlip = { fx("dust", "body", "F1", nil, { size = 0.6 }) },
	deathCurl = { fx("dust", "body", "F0.8", nil, { size = 0.6 }) },
}

-- The crow: feathers on every blow and fall, the wail's rings.
local CROW: { [string]: { Fx } } = {
	wail = { fx("screech", "mouth", "W", nil, { size = 0.7 }) },
	shot = { fx("feathers", "body", "W", nil, { size = 0.4 }) },
	rake = { fx("feathers", "body", "W", nil, { size = 0.6 }) },
	stoop = { fx("feathers", "body", "W", nil, { size = 0.7 }) },
	deathFall = { fx("feathers", "body", "A1", nil, { size = 0.7 }), fx("dust", "body", "F1", nil, { size = 0.5 }) },
	deathFallBack = { fx("feathers", "body", "A1", nil, { size = 0.7 }), fx("dust", "body", "F1", nil, { size = 0.5 }) },
}

-- The bat: leather wings (no feathers), the wail's rings, the fall's dust.
local BAT: { [string]: { Fx } } = {
	wail = { fx("screech", "mouth", "W", nil, { size = 0.6 }) },
	deathFall = { fx("dust", "body", "F1", nil, { size = 0.5 }) },
	deathFallBack = { fx("dust", "body", "F1", nil, { size = 0.5 }) },
}

local HARE: { [string]: { Fx } } = {
	deathHop = { fx("dust", "feet", "F0.6", nil, { size = 0.4 }) },
	deathSide = { fx("dust", "body", "F1", nil, { size = 0.4 }) },
}

-- The rot ent: splinters off the branch blows, leaves shaken out of the crown, the slam into the ground, the fall.
local ENT: { [string]: { Fx } } = {
	branch = { fx("splinters", "mouth", "W", nil, { size = 0.7 }), fx("leaves", "top", "W", nil, { size = 0.5 }) },
	sweep = { fx("splinters", "mouth", "W"), fx("leaves", "top", "W", nil, { size = 0.7 }) },
	slam = { fx("slam", "front", "W", nil, { size = 1.1 }), fx("leaves", "top", "W") },
	crush = { fx("slam", "front", "W", nil, { size = 1.3 }), fx("leaves", "top", "W", nil, { size = 1.2 }) },
	fling = { fx("leaves", "top", "W", nil, { size = 0.6 }), fx("splinters", "mouth", "W", nil, { size = 0.5 }) },
	rustle = { fx("leaves", "top", "F0.3", nil, { size = 0.5 }) },
	creak = { fx("leaves", "top", "F0.5", nil, { size = 0.3 }) },
	deathTopple = {
		fx("leaves", "top", "A1", nil, { size = 0.8 }),
		fx("splinters", "body", "F0.75"),
		fx("dust", "body", "F0.75", nil, { size = 1.5 }),
	},
	deathFallForward = {
		fx("leaves", "top", "A1", nil, { size = 0.8 }),
		fx("splinters", "front", "F0.75"),
		fx("dust", "front", "F0.75", nil, { size = 1.5 }),
	},
}

local CAT: { [string]: { Fx } } = {
	leap = { fx("dust", "feet", "W", nil, { size = 0.6 }) },
	pounce = { fx("dust", "feet", "W", nil, { size = 0.6 }) },
	deathSide = { fx("dust", "body", "F1", nil, { size = 0.5 }) },
	deathSlump = { fx("dust", "body", "F1", nil, { size = 0.5 }) },
}

---------------------------------------------------------------- flyers (Data/FlyerStyles)

-- The vulture: feathers on its blows and its fall, the wail's rings from the beak.
local VULTURE: { [string]: { Fx } } = {
	volley = { fx("feathers", "body", "W", nil, { size = 0.4 }) },
	wail = { fx("screech", "mouth", "W") },
	screech = { fx("screech", "mouth", "W", nil, { size = 0.6 }) },
	rake = { fx("feathers", "body", "W", nil, { size = 0.7 }) },
	stoop = { fx("feathers", "body", "W", nil, { size = 0.8 }) },
	ruffle = { fx("feathers", "body", "F0.3", nil, { size = 0.5 }) },
	deathL = { fx("feathers", "body", "A1"), fx("dust", "body", "W", nil, { size = 0.8 }) },
	deathR = { fx("feathers", "body", "A1"), fx("dust", "body", "W", nil, { size = 0.8 }) },
}

-- The harpy: lightning crackling between its wing tips as it gathers and flaring on the release (the bolt itself flies
-- from the server's shot), a storm-tinted wail, feathers.
local HARPY: { [string]: { Fx } } = {
	fling = {
		fx("arc", "wings", "A0.35", "W", { element = "lightning" }),
		fx("flare", "wings", "W", nil, { element = "lightning" }),
	},
	wail = { fx("screech", "head", "W", nil, { element = "lightning" }) },
	screech = { fx("screech", "head", "W", nil, { size = 0.6, element = "lightning" }) },
	rake = { fx("feathers", "body", "W", nil, { size = 0.7 }) },
	stoop = { fx("feathers", "body", "W", nil, { size = 0.8 }) },
	ruffle = { fx("feathers", "body", "F0.3", nil, { size = 0.5 }) },
	deathL = { fx("feathers", "body", "A1"), fx("dust", "body", "W", nil, { size = 0.8 }) },
	deathR = { fx("feathers", "body", "A1"), fx("dust", "body", "W", nil, { size = 0.8 }) },
	deathBackL = { fx("feathers", "body", "A1"), fx("dust", "body", "W", nil, { size = 0.8 }) },
	deathBackR = { fx("feathers", "body", "A1"), fx("dust", "body", "W", nil, { size = 0.8 }) },
}

local function freezeAll(list: { [string]: { Fx } }): { [string]: { Fx } }
	for _, items in list do
		if not table.isfrozen(items) then
			table.freeze(items)
		end
	end
	return table.freeze(list)
end

-- Style id -> action name -> its effects.
MotionFx.STYLES = table.freeze({
	wyvern = freezeAll(WYVERN),
	wyvernRegular = freezeAll(WYVERN_REGULAR),
	specter = freezeAll(SPECTER),
	iceElemental = freezeAll(ICE_ELEMENTAL),
	canine = freezeAll(CANINE),
	bear = freezeAll(BEAR),
	boar = freezeAll(BOAR),
	mammoth = freezeAll(MAMMOTH),
	spider = freezeAll(SPIDER),
	scorpion = freezeAll(SCORPION),
	lizard = freezeAll(LIZARD),
	serpent = freezeAll(SERPENT),
	crow = freezeAll(CROW),
	bat = freezeAll(BAT),
	toad = freezeAll(TOAD),
	hare = freezeAll(HARE),
	ent = freezeAll(ENT),
	cat = freezeAll(CAT),
	vulture = freezeAll(VULTURE),
	harpy = freezeAll(HARPY),
} :: { [string]: { [string]: { Fx } } })

-- Style id -> the puff a hit knocks off (at the hit's flinch; Fx `from` / `to` unused).
MotionFx.HIT = table.freeze({
	crow = fx("feathers", "body", "W", nil, { size = 0.4 }),
	vulture = fx("feathers", "body", "W", nil, { size = 0.5 }),
	harpy = fx("feathers", "body", "W", nil, { size = 0.5 }),
	ent = fx("splinters", "body", "W", nil, { size = 0.5 }),
	iceElemental = fx("snow", "chest", "W", nil, { size = 0.5 }),
	specter = fx("wisps", "chest", "W", nil, { size = 0.5 }),
} :: { [string]: Fx })

-- The effects of an action of a style (nil: none).
function MotionFx.get(styleId: string, actionName: string): { Fx }?
	local style = MotionFx.STYLES[styleId]
	return if style then style[actionName] else nil
end

MotionFx.mark = mark

return MotionFx
