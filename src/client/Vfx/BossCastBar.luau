--!strict
-- S160 (owner 2026-10-21: "boss abilities are barely visible"): what a boss's (or an Elite II's) cast shows besides
-- the ground (Logic/BossCast, Config.BossCast):
--   cast    a cast bar over the caster (above its name plate, always on top): the ability's name and a bar filling to
--           the blow in the telegraph's vivid colour; a big attack's bar is thicker, its edge flares faster towards the
--           blow. One bar per caster: a new cast replaces it; it goes at the blow or when the caster is gone.
--   banner  a warning across the upper middle of the screen for a big attack (name and what to do), with a short
--           alarm; it scales in, pulses and fades.
--           UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"): the
--           warning is UI/Notify's alert line (at most 28 characters) in the band under the target, on a dark plate
--           edged in the telegraph's colour, until the blow; no separate layer over the windows any more.
-- Both are interface, so low quality keeps them (they are the warning itself). The time runs on Vfx/Clock (AnimLab
-- freezes it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local BossCast = require(ReplicatedStorage.Shared.Logic.BossCast)
local Clock = require(script.Parent.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local MonsterBox = require(script.Parent.Parent.Util.MonsterBox)
local Notify = require(script.Parent.Parent.UI.Notify)
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
local banner: Notify.Handle? = nil -- the warning on the alert line
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

-- Studs above the root: over the caster's top and its name plate (MonsterPlateController sits at top + 1.4). `top`:
-- the world height of the look's top the plate stands on (MonsterViewController.top); without it the top of the body's
-- box (Util/MonsterBox: a monster's look, never its blocker column, owner 2026-11-10).
local function offsetOf(caster: Model, root: BasePart, top: number?): number
	if top then
		return top - root.Position.Y + 1.4
	end
	local box, size = MonsterBox.of(caster)
	return box.Position.Y + size.Y / 2 - root.Position.Y + 1.4
end

local function newBar(caster: Model, root: BasePart, big: boolean, top: number?): Bar?
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
	gui.StudsOffsetWorldSpace = Vector3.new(0, offsetOf(caster, root, top), 0)
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
	if next(bars) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function run()
	if not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
end

-- A cast bar over `caster`: `name` filling over `seconds` (at least Logic/BossCast.MIN_BAR) in `color`; `top`: the
-- world height of the caster's top its name plate uses (MonsterViewController.top), nil for its body's box.
function BossCastBar.cast(caster: Model, name: string, seconds: number, color: Color3, big: boolean, top: number?)
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
	local bar = if kept then kept else newBar(caster, root, big, top)
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

-- The warning banner of a big attack: `text` in `color` for `seconds` (at least Config.BossCast.bannerSeconds), on
-- UI/Notify's alert line; a newer warning takes the older one's place (its blow has landed).
function BossCastBar.banner(text: string, color: Color3, seconds: number)
	if text == "" then
		return
	end
	if banner then
		banner.close()
	end
	local vivid = Color3.fromHex(BossCast.vivid("#" .. color:ToHex()))
	banner = Notify.alert(text, math.max(CFG.bannerSeconds, seconds), vivid)
end

-- Drops the bar of a caster (it died, the cast was cancelled).
function BossCastBar.stop(caster: Model)
	dropBar(caster)
end

return BossCastBar
