--!strict
-- Shared client state of the guide (S25, DESIGN §23): the one navigation target (same shape as
-- QuestTrack.Target plus a label), whether the character walks there by itself, the distance and the next map
-- on the way for the HUD bar, and requests for the world map (open centred on something, open a card).
-- NavController writes the live values; the world map, the minimap and the HUD read them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)

local scope = Fusion.scoped(Fusion)

-- Map-relative target. `npc` makes the guide stop in front of the NPC and face it; `follow` (party member)
-- moves with them; `kind`/`id` say which map card it came from; `labelKey` or `label` name it in the HUD.
export type Target = {
	map: string,
	x: number,
	z: number,
	npc: string?,
	kind: string?,
	id: string?,
	labelKey: string?,
	label: string?,
	follow: number?, -- userId of a party member
}

-- What the world map should show when it opens (or right away when it is open).
export type Focus = {
	map: string?, -- nil = the player's map
	x: number?, -- nil = the player
	z: number?,
	zoom: number?, -- zoom index
	card: { kind: string, id: string }?,
}

return {
	Target = scope:Value(nil :: Target?),
	Walking = scope:Value(false),
	-- Studs to the target (or to the portal on the way) and the next map when the target is elsewhere.
	Distance = scope:Value(nil :: number?),
	Via = scope:Value(nil :: string?),
	-- /navdebug line (points, recomputes per minute); nil = off.
	Debug = scope:Value(nil :: string?),
	MapFocus = scope:Value(nil :: Focus?),
}
