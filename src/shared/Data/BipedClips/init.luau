--!strict
-- Template animation: mocap clips (Mixamo, baked by tools/anim/bake_biped.py from the list in tools/anim/clips.csv;
-- format in Logic/BipedClip) the biped template (Logic/BipedMotion) plays: locomotion under its procedural layers, and
-- since 2026-10-31 the armed stance, actions, hit reactions and falls (Data/BipedStyles ClipRef). Names are the
-- motion's own (Data/BipedStyles, Data/BossStyles).

local ALL: { [string]: any } = {
	battlecry = require("@self/battlecry"),
	fallBack = require("@self/fallBack"),
	fallBack2 = require("@self/fallBack2"),
	fallFwd = require("@self/fallFwd"),
	greatJump = require("@self/greatJump"),
	greatSlash = require("@self/greatSlash"),
	greatSpin = require("@self/greatSpin"),
	guardIdle = require("@self/guardIdle"),
	guardWalk = require("@self/guardWalk"),
	hitBack = require("@self/hitBack"),
	hitFront = require("@self/hitFront"),
	hitLeft = require("@self/hitLeft"),
	hitRight = require("@self/hitRight"),
	idle = require("@self/idle"),
	idleLook = require("@self/idleLook"),
	idleShift = require("@self/idleShift"),
	impact2 = require("@self/impact2"),
	impact3 = require("@self/impact3"),
	jog = require("@self/jog"),
	magic1h = require("@self/magic1h"),
	mutantDeath = require("@self/mutantDeath"),
	mutantIdle = require("@self/mutantIdle"),
	mutantSlam = require("@self/mutantSlam"),
	mutantSwipe = require("@self/mutantSwipe"),
	mutantWalk = require("@self/mutantWalk"),
	run = require("@self/run"),
	standUp = require("@self/standUp"),
	swordBackhand = require("@self/swordBackhand"),
	swordChop = require("@self/swordChop"),
	swordHop = require("@self/swordHop"),
	swordLeap = require("@self/swordLeap"),
	swordSlash = require("@self/swordSlash"),
	swordSweep = require("@self/swordSweep"),
	throw = require("@self/throw"),
	walk = require("@self/walk"),
}

local BipedClips = {}

function BipedClips.get(name: string): any?
	return ALL[name]
end

function BipedClips.names(): { string }
	local out = {}
	for name in ALL do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

return BipedClips
