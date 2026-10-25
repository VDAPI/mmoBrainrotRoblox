--!strict
-- Template animation: mocap clips (Mixamo, baked by tools/anim/bake_biped.py; format in Logic/BipedClip) the biped
-- template (Logic/BipedMotion) plays under its procedural layers. Names are the motion's own (Data/BipedStyles).

local ALL: { [string]: any } = {
	idle = require("@self/idle"),
	idleLook = require("@self/idleLook"),
	idleShift = require("@self/idleShift"),
	jog = require("@self/jog"),
	run = require("@self/run"),
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
