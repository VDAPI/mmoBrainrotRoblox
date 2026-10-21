--!strict
-- S160 (owner 2026-10-21: "boss abilities are barely visible"): what a boss's (or an Elite II's) cast shows besides
-- the ground (Logic/BossCast, Config.BossCast):
--   cast    a cast bar over the caster (above its name plate, always on top): the ability's name and a bar filling to
--           the blow in the telegraph's vivid colour; a big attack's bar is thicker, its edge flares faster towards the
--           blow. One bar per caster: a new cast replaces it; it goes at the blow or when the caster is gone.
--   banner  a warning across the upper middle of the screen for a big attack (name and what to do), with a short
--           alarm; it scales in, pulses and fades.
-- Both are interface, so low quality keeps them (they are the warning itself). The time runs on Vfx/Clock (AnimLab
-- freezes it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BossCast = require(ReplicatedStorage.Shared.Logic.BossCast)
local Clock = require(script.Parent.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Theme = require(script.Parent.Parent.UI.Theme)

local BossCastBar = {}

local CFG = Config.BossCast
local WHITE = Color3.new(1, 1, 1)
local IRON = Color3.fromHex("#1B1714")
local EDGE = Color3.fromHex("#0A0706")
local FONT = Theme.Fonts.Display
local BAR_SIZE = Vector2.new(250, 44)
local BAR_SIZE_BIG = Vector2.new(290, 52)

type Bar = {
	caster: Model,
	gui: BillboardGui,
	fill: Frame,
	stroke: UIStroke,
	label: TextLabel,
	start: number,
	seconds: number,
	big: boolean,
}

local bars: { [Model]: Bar } = {}
local banner: { gui: ScreenGui, frame: Frame, label: TextLabel, stroke: UIStroke, scale: UIScale, start: number, seconds: number }? =
	nil
local connection: RBXScriptConnection? = nil
local folder: Folder? = nil

local function guiRoot(): Instance?
	local player = Players.LocalPlayer
	return player and player:FindFirstChildOfClass("PlayerGui")
end

local function barFolder(): Folder?
	if folder and folder.Parent then
		return folder
	end
	local root = guiRoot()
	if not root then
		return nil
	end
	local f = Instance.new("Folder")
	f.Name = "BossCastBars"
	f.Parent = root
	folder = f
	return f
end

-- Studs above the root: over the model's top and its name plate (MonsterPlateController sits at top + 1.4).
local function offsetOf(caster: Model, root: BasePart): number
	local box, size = caster:GetBoundingBox()
	return box.Position.Y + size.Y / 2 - root.Position.Y + 1.4
end

local function newBar(caster: Model, root: BasePart, big: boolean): Bar?
	local parent = barFolder()
	if not parent then
		return nil
	end
	local px = if big then BAR_SIZE_BIG else BAR_SIZE
	local gui = Instance.new("BillboardGui")
	gui.Name = "BossCast"
	gui.Adornee = root
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = CFG.barRange
	gui.ResetOnSpawn = false
	gui.Size = UDim2.fromOffset(px.X, px.Y)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetOf(caster, root), 0)
	-- above the 62 px name plate centred on the same point
	gui.SizeOffset = Vector2.new(0, 31 / px.Y + 0.6)
	local label = Instance.new("TextLabel")
	label.Name = "Name"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0.55)
	label.FontFace = FONT
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.TextStrokeColor3 = EDGE
	label.TextStrokeTransparency = 0
	label.Parent = gui
	local back = Instance.new("Frame")
	back.Name = "Bar"
	back.AnchorPoint = Vector2.new(0.5, 1)
	back.Position = UDim2.fromScale(0.5, 1)
	back.Size = UDim2.new(1, -8, 0.38, 0)
	back.BackgroundColor3 = IRON
	back.BackgroundTransparency = 0.15
	back.BorderSizePixel = 0
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = back
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = if big then 3 else 2
	stroke.Color = WHITE
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = back
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BorderSizePixel = 0
	fill.Parent = back
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 4)
	fillCorner.Parent = fill
	gui.Parent = parent
	return {
		caster = caster,
		gui = gui,
		fill = fill,
		stroke = stroke,
		label = label,
		start = 0,
		seconds = 1,
		big = big,
	}
end

local function dropBar(caster: Model)
	local bar = bars[caster]
	if bar then
		bar.gui:Destroy()
		bars[caster] = nil
	end
end

local function step()
	local now = Clock.now()
	for caster, bar in bars do
		local k = (now - bar.start) / bar.seconds
		if k >= 1.05 or caster.Parent == nil then
			dropBar(caster)
			continue
		end
		k = math.clamp(k, 0, 1)
		bar.fill.Size = UDim2.fromScale(k, 1)
		-- the edge flares faster towards the blow (a big attack harder)
		local beat = 0.5 + 0.5 * math.cos(now * (6 + 18 * k) * (if bar.big then 1.4 else 1))
		bar.stroke.Transparency = 0.6 * beat * (1 - k * 0.5)
	end
	local b = banner
	if b then
		local t = now - b.start
		if t >= b.seconds then
			b.gui:Destroy()
			banner = nil
		else
			local appear = math.clamp(t / 0.15, 0, 1)
			local fade = math.clamp((b.seconds - t) / 0.4, 0, 1)
			b.scale.Scale = 0.7 + 0.3 * (1 - (1 - appear) ^ 3) + 0.04 * math.sin(t * 14) * fade
			local alpha = 1 - math.min(appear, fade)
			b.label.TextTransparency = alpha
			b.label.TextStrokeTransparency = alpha
			b.frame.BackgroundTransparency = 0.35 + 0.65 * alpha
			b.stroke.Transparency = alpha + (1 - alpha) * 0.5 * (0.5 + 0.5 * math.cos(t * 16))
		end
	end
	if next(bars) == nil and banner == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function run()
	if not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
end

-- A cast bar over `caster`: `name` filling over `seconds` (at least Logic/BossCast.MIN_BAR) in `color`.
function BossCastBar.cast(caster: Model, name: string, seconds: number, color: Color3, big: boolean)
	local root = caster:FindFirstChild("HumanoidRootPart") or caster.PrimaryPart
	if not root or not root:IsA("BasePart") or name == "" then
		return
	end
	local camera = Workspace.CurrentCamera
	if camera and (root.Position - camera.CFrame.Position).Magnitude > CFG.barRange then
		return
	end
	local existing: Bar? = bars[caster]
	if existing and existing.big ~= big then
		dropBar(caster)
	end
	local kept = bars[caster]
	local bar = if kept then kept else newBar(caster, root, big)
	if not bar then
		return
	end
	bars[caster] = bar
	local vivid = Color3.fromHex(BossCast.vivid("#" .. color:ToHex()))
	bar.label.Text = name
	bar.label.TextColor3 = vivid:Lerp(WHITE, 0.55)
	bar.fill.BackgroundColor3 = vivid
	bar.stroke.Color = vivid:Lerp(WHITE, 0.4)
	bar.start = Clock.now()
	bar.seconds = BossCast.barSeconds(seconds)
	bar.fill.Size = UDim2.fromScale(0, 1)
	run()
end

-- The warning banner of a big attack: `text` in `color` for `seconds` (at least Config.BossCast.bannerSeconds).
function BossCastBar.banner(text: string, color: Color3, seconds: number)
	local root = guiRoot()
	if not root or text == "" then
		return
	end
	if banner then
		banner.gui:Destroy()
		banner = nil
	end
	local vivid = Color3.fromHex(BossCast.vivid("#" .. color:ToHex()))
	local gui = Instance.new("ScreenGui")
	gui.Name = "BossWarning"
	gui.DisplayOrder = 40
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.24)
	frame.Size = UDim2.new(0.7, 0, 0, 64)
	frame.BackgroundColor3 = IRON
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(760, 64)
	constraint.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = vivid
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local scale = Instance.new("UIScale")
	scale.Scale = 0.7
	scale.Parent = frame
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, -24, 1, -10)
	label.Position = UDim2.fromOffset(12, 5)
	label.FontFace = FONT
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = vivid:Lerp(WHITE, 0.35)
	label.TextStrokeColor3 = EDGE
	label.TextStrokeTransparency = 0
	label.Parent = frame
	gui.Parent = root
	banner = {
		gui = gui,
		frame = frame,
		label = label,
		stroke = stroke,
		scale = scale,
		start = Clock.now(),
		seconds = math.max(CFG.bannerSeconds, seconds),
	}
	run()
end

-- Drops the bar of a caster (it died, the cast was cancelled).
function BossCastBar.stop(caster: Model)
	dropBar(caster)
end

return BossCastBar
