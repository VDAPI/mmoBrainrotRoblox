--!strict
-- Effect textures on the client (S112, Data/VfxTextures, docs/ANIMACJE.md "Tekstury efektów"): the only place that
-- turns the texture data into Enum values and instance properties. A texture is used only when it is enabled
-- (Config.Vfx.textures, `/animlab vfx tex on|off`), has an uploaded id, did not fail Textures.check and the pieces do
-- not go into a ViewportFrame (the skills-window preview draws no particles, beams or trails); otherwise every setter
-- returns false and leaves the instance as it was, and the caller keeps the old look.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Pool = require(script.Parent.Pool)
local VfxTextures = require(ReplicatedStorage.Shared.Data.VfxTextures)

local Textures = {}

Textures.enabled = Config.Vfx.textures

-- Keys whose image did not load (Textures.check): they fall back like an empty id.
local failed: { [string]: boolean } = {}

local LAYOUTS: { [string]: Enum.ParticleFlipbookLayout } = {
	["2x2"] = Enum.ParticleFlipbookLayout.Grid2x2,
	["4x4"] = Enum.ParticleFlipbookLayout.Grid4x4,
	["8x8"] = Enum.ParticleFlipbookLayout.Grid8x8,
}
local MODES: { [string]: Enum.ParticleFlipbookMode } = {
	loop = Enum.ParticleFlipbookMode.Loop,
	oneShot = Enum.ParticleFlipbookMode.OneShot,
	pingPong = Enum.ParticleFlipbookMode.PingPong,
	random = Enum.ParticleFlipbookMode.Random,
}
local LOOP_FPS = 20 -- a looping flipbook (fire): 16-24 frames per second
local CHECK_SECONDS = 10
local DEFAULT_BEAM_LENGTH = 4

-- The id to use for `key`, nil when it must fall back (see the header).
function Textures.id(key: string): string?
	if not Textures.enabled or failed[key] or Pool.inViewport() then
		return nil
	end
	return VfxTextures.idOf(key)
end

-- Texture, LightEmission (from the data unless `emission` is given), LightInfluence 0 for glowing textures, and the
-- flipbook (layout, mode, frame rate: the whole sequence over the longest life for oneShot). False without a texture.
function Textures.particle(e: ParticleEmitter, key: string, emission: number?): boolean
	local id = Textures.id(key)
	local def = VfxTextures.get(key)
	if not id or not def then
		return false
	end
	e.Texture = id
	local glow = emission or def.emission or 1
	e.LightEmission = glow
	e.LightInfluence = if glow > 0 then 0 else 1
	local layout = def.grid and LAYOUTS[def.grid]
	if layout then
		e.FlipbookLayout = layout
		e.FlipbookMode = MODES[def.mode or "oneShot"] or Enum.ParticleFlipbookMode.OneShot
		if def.mode == "loop" then
			e.FlipbookFramerate = NumberRange.new(LOOP_FPS)
			e.FlipbookStartRandom = true
		else
			e.FlipbookFramerate = NumberRange.new((def.frames or 16) / math.max(0.05, e.Lifetime.Max))
			e.FlipbookStartRandom = false
		end
	else
		e.FlipbookLayout = Enum.ParticleFlipbookLayout.None
	end
	return true
end

-- Takes the texture off an emitter (a holder reused while textures are off or failed).
function Textures.plainParticle(e: ParticleEmitter)
	e.Texture = ""
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.None
	e.LightInfluence = 0
end

-- Texture, Wrap for tiling textures (Stretch otherwise, once over the beam), TextureLength of a tiling texture
-- (default 4 studs), TextureSpeed (default 0),
-- glowing (LightEmission 1, LightInfluence 0). False without a texture.
function Textures.beam(b: Beam, key: string, opts: { speed: number?, length: number? }?): boolean
	local id = Textures.id(key)
	local def = VfxTextures.get(key)
	if not id or not def then
		return false
	end
	local o: { speed: number?, length: number? } = opts or {}
	b.Texture = id
	-- Wrap repeats every TextureLength studs; Stretch repeats the texture TextureLength times over the whole beam
	b.TextureMode = if def.wrap then Enum.TextureMode.Wrap else Enum.TextureMode.Stretch
	b.TextureLength = if def.wrap then o.length or DEFAULT_BEAM_LENGTH else 1
	b.TextureSpeed = o.speed or 0
	b.LightEmission = def.emission or 1
	b.LightInfluence = 0
	return true
end

function Textures.trail(t: Trail, key: string): boolean
	local id = Textures.id(key)
	if not id then
		return false
	end
	t.Texture = id
	t.TextureMode = Enum.TextureMode.Stretch
	t.LightInfluence = 0
	return true
end

function Textures.decal(d: Decal, key: string): boolean
	local id = Textures.id(key)
	if not id then
		return false
	end
	d.Texture = id
	return true
end

-- Pool.dress: a holder's child gets the texture of its key, or loses it.
Pool.dress = function(kind: Pool.HolderKind, child: Instance, key: string)
	if kind == "emitter" and child:IsA("ParticleEmitter") then
		if not Textures.particle(child, key) then
			Textures.plainParticle(child)
		end
	elseif kind == "beam" and child:IsA("Beam") then
		if not Textures.beam(child, key) then
			child.Texture = ""
		end
	elseif kind == "decal" and child:IsA("Decal") then
		if not Textures.decal(child, key) then
			child.Texture = ""
		end
	elseif kind == "surface" and child:IsA("SurfaceGui") then
		local image = child:FindFirstChild("Image")
		if image and image:IsA("ImageLabel") then
			image.Image = Textures.id(key) or ""
		end
	end
end

-- AnimLab `vfx tex`: loads every uploaded id into a hidden ImageLabel and, after 10 s, answers key -> "ok" or
-- "not loaded" (IsLoaded on the instance: PreloadAsync on a bare id fails in Studio even for good images), and for
-- flipbooks the FlipbookIncompatible message of a trial emitter ("" = fine). Keys that did not load are remembered
-- and fall back from then on (Textures.id). Yields.
function Textures.check(): { [string]: string }
	local result: { [string]: string } = {}
	local player = Players.LocalPlayer
	local gui = Instance.new("ScreenGui")
	gui.Name = "VaelthornTextureCheck"
	gui.Enabled = true
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local anchor = Instance.new("Part")
	anchor.Name = "VaelthornTextureCheck"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Position = Vector3.new(0, -500, 0)
	anchor.Parent = workspace
	local labels: { [string]: ImageLabel } = {}
	local trials: { [string]: ParticleEmitter } = {}
	for _, key in VfxTextures.ORDER do
		local id = VfxTextures.idOf(key)
		local def = VfxTextures.get(key)
		if id and def then
			local label = Instance.new("ImageLabel")
			label.Size = UDim2.fromOffset(1, 1)
			label.ImageTransparency = 0.99
			label.BackgroundTransparency = 1
			label.Image = id
			label.Parent = gui
			labels[key] = label
			if def.grid then
				local e = Instance.new("ParticleEmitter")
				e.Rate = 0
				e.Texture = id
				e.FlipbookLayout = LAYOUTS[def.grid] or Enum.ParticleFlipbookLayout.None
				e.Parent = anchor
				trials[key] = e
			end
		else
			result[key] = "empty"
		end
	end
	task.wait(CHECK_SECONDS)
	for key, label in labels do
		local ok = label.IsLoaded
		result[key] = if ok then "ok" else "not loaded"
		if ok then
			failed[key] = nil
		else
			failed[key] = true
		end
		local trial = trials[key]
		if trial and trial.FlipbookIncompatible ~= "" then
			result[key .. ".flipbook"] = trial.FlipbookIncompatible
		end
	end
	gui:Destroy()
	anchor:Destroy()
	return result
end

-- Forgets the failures of an earlier check (AnimLab `vfx tex on`).
function Textures.clearFailed()
	table.clear(failed)
end

return Textures
