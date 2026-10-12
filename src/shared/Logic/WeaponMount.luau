--!strict
-- Where a real weapon model sits in the hand (S52, docs/GRAFIKA.md 3.3). Pure vector maths without the Roblox API,
-- so tests check the Grip convention in Lune; EquipmentService builds the same frame with CFrame.fromMatrix.
-- Grip frame of a model: +Y = tip / head / front of a crossbow / top edge of an off-hand (the length axis), +X =
-- cutting edge, axe head, back of a bow, top of a crossbow, face of a shield, front of an orb or relic. A mount
-- (WeaponLooks.MOUNTS) says which hand-frame directions those axes take, where the grip point is and how the model
-- is tilted. Hand frame: WeaponLooks (origin at the palm, -Z = forward, +Y = up the arm, +X = right).

local WeaponLooks = require("../Data/WeaponLooks")

export type Vec = { number }

local WeaponMount = {}

local AXES: { [string]: Vec } = {
	["+X"] = { 1, 0, 0 },
	["-X"] = { -1, 0, 0 },
	["+Y"] = { 0, 1, 0 },
	["-Y"] = { 0, -1, 0 },
	["+Z"] = { 0, 0, 1 },
	["-Z"] = { 0, 0, -1 },
}

local function cross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

local function dot(a: Vec, b: Vec): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

-- Rotation of CFrame.Angles(rx, ry, rz) (degrees) applied to v: Rx * Ry * Rz * v.
function WeaponMount.rotate(v: Vec, rot: Vec?): Vec
	if not rot then
		return v
	end
	local rx, ry, rz = math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3])
	local x, y, z = v[1], v[2], v[3]
	x, y = x * math.cos(rz) - y * math.sin(rz), x * math.sin(rz) + y * math.cos(rz)
	x, z = x * math.cos(ry) + z * math.sin(ry), -x * math.sin(ry) + z * math.cos(ry)
	y, z = y * math.cos(rx) - z * math.sin(rx), y * math.sin(rx) + z * math.cos(rx)
	return { x, y, z }
end

-- Unit vector of an axis name ("+X" .. "-Z"), or nil for a typo.
function WeaponMount.axis(name: string): Vec?
	return AXES[name]
end

-- Hand-frame directions of the Grip axes X, Y, Z of a mount (before the tilt).
function WeaponMount.basis(mount: WeaponLooks.Mount): (Vec, Vec, Vec)
	local x = AXES[mount.x] or AXES["+Y"]
	local y = AXES[mount.y] or AXES["-Z"]
	return x, y, cross(x, y)
end

-- A point given in the Grip frame (grip point = origin), in the hand frame.
function WeaponMount.toHand(mount: WeaponLooks.Mount, p: Vec): Vec
	local x, y, z = WeaponMount.basis(mount)
	local local3 = {
		x[1] * p[1] + y[1] * p[2] + z[1] * p[3],
		x[2] * p[1] + y[2] * p[2] + z[2] * p[3],
		x[3] * p[1] + y[3] * p[2] + z[3] * p[3],
	}
	local turned = WeaponMount.rotate(local3, mount.tilt)
	local at = mount.at or { 0, 0, 0 }
	return { at[1] + turned[1], at[2] + turned[2], at[3] + turned[3] }
end

-- A hand-frame point in the Grip frame of a mount (inverse of toHand).
function WeaponMount.toGrip(mount: WeaponLooks.Mount, p: Vec): Vec
	local at = mount.at or { 0, 0, 0 }
	local d = { p[1] - at[1], p[2] - at[2], p[3] - at[3] }
	if mount.tilt then
		local t = mount.tilt
		-- Inverse of Rx * Ry * Rz: Rz^-1 * Ry^-1 * Rx^-1, one axis at a time.
		d = WeaponMount.rotate(d, { -t[1], 0, 0 })
		d = WeaponMount.rotate(d, { 0, -t[2], 0 })
		d = WeaponMount.rotate(d, { 0, 0, -t[3] })
	end
	local x, y, z = WeaponMount.basis(mount)
	return { dot(d, x), dot(d, y), dot(d, z) }
end

-- Corners of every piece of a Part look in the hand frame.
function WeaponMount.corners(look: WeaponLooks.Look): { Vec }
	local out = {}
	for _, piece in look.pieces do
		local h = { piece.size[1] / 2, piece.size[2] / 2, piece.size[3] / 2 }
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local r = WeaponMount.rotate({ h[1] * sx, h[2] * sy, h[3] * sz }, piece.rot)
					table.insert(out, { piece.pos[1] + r[1], piece.pos[2] + r[2], piece.pos[3] + r[3] })
				end
			end
		end
	end
	return out
end

export type Span = { min: Vec, max: Vec, length: number, grip: number }

-- Box of a Part look in the Grip frame of a mount: min / max per axis, the length along +Y and the grip point as a
-- fraction of that length from the bottom (the numbers of docs/GRAFIKA.md 3.4).
function WeaponMount.lookSpan(look: WeaponLooks.Look, mount: WeaponLooks.Mount): Span
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, corner in WeaponMount.corners(look) do
		local q = WeaponMount.toGrip(mount, corner)
		for i = 1, 3 do
			lo[i] = math.min(lo[i], q[i])
			hi[i] = math.max(hi[i], q[i])
		end
	end
	local length = hi[2] - lo[2]
	return { min = lo, max = hi, length = length, grip = if length > 0 then -lo[2] / length else 0 }
end

-- Grip-frame position of a real model's box centre line at height `y` (fraction of the length from the bottom):
-- the palm is on the handle, `hold` away from that line (EquipmentService.buildFromModel).
function WeaponMount.assetPoint(asset: WeaponLooks.Asset, y: number): Vec
	local hold = asset.hold or { 0, 0 }
	return { -hold[1] * asset.length, (y - asset.grip) * asset.length, -hold[2] * asset.length }
end

-- Hand-frame position of the far end (tip) of a real model: the top of its length axis.
function WeaponMount.assetTip(asset: WeaponLooks.Asset, mount: WeaponLooks.Mount): Vec
	return WeaponMount.toHand(mount, WeaponMount.assetPoint(asset, 1))
end

return WeaponMount
