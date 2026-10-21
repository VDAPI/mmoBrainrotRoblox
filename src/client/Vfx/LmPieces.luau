--!strict
-- W30: the registry of the extra skill pieces kept in their own modules (prefix per author: `lm` = Hunter and Mage,
-- client/Vfx/LmHunterMage). VfxController asks it for a piece the old chain (Vfx/Library) does not know, for the
-- cast / release pieces of SkillVfx (castFx, releaseFx) and for a projectile's own flight (SkillVfx flight). A piece
-- module returns { pieces = { [name]: Piece }, flights = { [name]: Flight } }; names must not repeat.

local LmTypes = require(script.Parent.LmTypes)

export type Ctx = LmTypes.Ctx
export type Piece = LmTypes.Piece
export type Flight = LmTypes.Flight

local pieces: { [string]: Piece } = {}
local flights: { [string]: Flight } = {}

local function add(module: { pieces: { [string]: Piece }?, flights: { [string]: Flight }? })
	local list: { [string]: Piece } = module.pieces or {}
	for name, fn in list do
		assert(pieces[name] == nil, `LmPieces: duplicate piece {name}`)
		pieces[name] = fn
	end
	local own: { [string]: Flight } = module.flights or {}
	for name, fn in own do
		assert(flights[name] == nil, `LmPieces: duplicate flight {name}`)
		flights[name] = fn
	end
end

add(require(script.Parent.LmHunterMage) :: any)

return {
	pieces = pieces,
	flights = flights,
}
