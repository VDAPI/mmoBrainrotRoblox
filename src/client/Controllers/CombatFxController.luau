--!strict
-- Draws the server's batched "CombatFx" events locally (ARCHITECTURE §7):
--   dmg    : floating damage number (white, yellow "!" crit, red when we are hit, grey "Dodge") + hit flash
--   heal   : green "+N"
--   atk    : swing (melee) or projectile (arrow / bolt) from attacker to target
--   tele   : red ground telegraph that fills during the windup (circle / cone / line)
--   reward : "+EXP · +gold" above our character
-- Damage numbers can be turned off in the menu (settings.dmgNumbers); telegraphs and hits always show.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage.Shared.Util.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local CombatFxController = {
	Name = "CombatFxController",
	Deps = { "EffectsController" },
}

local player = Players.LocalPlayer

local NUMBER_SECONDS = 0.9
local POOL_SIZE = 40
local TELEGRAPH_COLOR = Color3.fromHex("#D64A3E")

local ELEMENT_COLORS: { [string]: Color3 } = {
	fire = Color3.fromHex("#FF7A1A"),
	ice = Color3.fromHex("#7FD4FF"),
	lightning = Color3.fromHex("#E8E25A"),
	poison = Color3.fromHex("#7ACB3A"),
}

local fxFolder: Folder
local guiFolder: Folder
local pool: { BillboardGui } = {}
local flashes: { [Model]: Highlight } = {}

-- Entity lookup ---------------------------------------------------------------------------------------------

local function findModel(entityId: string?): Model?
	if not entityId then
		return nil
	end
	if string.sub(entityId, 1, 1) == "p" then
		for _, other in Players:GetPlayers() do
			local character = other.Character
			if character and character:GetAttribute("EntityId") == entityId then
				return character
			end
		end
		return nil
	end
	local monsters = Workspace:FindFirstChild("Monsters")
	if monsters then
		for _, child in monsters:GetChildren() do
			if child:GetAttribute("EntityId") == entityId then
				return child :: Model
			end
		end
	end
	return nil
end

local function headPosition(model: Model): Vector3
	local cframe, size = model:GetBoundingBox()
	return cframe.Position + Vector3.new(0, size.Y / 2 + 0.5, 0)
end

local function centre(model: Model): Vector3
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else model:GetPivot().Position
end

-- Floating numbers ---------------------------------------------------------------------------------------

local function newBillboard(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "FloatingText"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(220, 60)
	gui.MaxDistance = 120
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Theme.Fonts.BodyBold
	label.TextScaled = false
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = guiFolder
	return gui
end

local function floatText(at: Vector3, text: string, color: Color3, size: number, rise: number?)
	local gui = table.remove(pool) or newBillboard()
	local label = gui:FindFirstChild("Label") :: TextLabel
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = at + Vector3.new((math.random() - 0.5) * 1.5, 0, (math.random() - 0.5) * 1.5)
	anchor.Parent = Workspace.Terrain
	gui.Adornee = anchor
	gui.StudsOffsetWorldSpace = Vector3.zero
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.3
	gui.Enabled = true
	local info = TweenInfo.new(NUMBER_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = Vector3.new(0, rise or 3, 0) }):Play()
	TweenService:Create(
		label,
		TweenInfo.new(
			NUMBER_SECONDS * 0.5,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In,
			0,
			false,
			NUMBER_SECONDS * 0.5
		),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()
	task.delay(NUMBER_SECONDS + 0.05, function()
		gui.Enabled = false
		(gui :: any).Adornee = nil
		anchor:Destroy()
		if #pool < POOL_SIZE then
			table.insert(pool, gui)
		else
			gui:Destroy()
		end
	end)
end

local function numbersEnabled(): boolean
	return State.Get({ "account", "settings", "dmgNumbers" }) ~= false
end

local function flash(model: Model)
	local highlight = flashes[model]
	if not highlight then
		local created = Instance.new("Highlight")
		created.FillColor = Color3.new(1, 1, 1)
		created.OutlineTransparency = 1
		created.DepthMode = Enum.HighlightDepthMode.Occluded
		created.Adornee = model
		created.Parent = guiFolder
		flashes[model] = created
		model.Destroying:Connect(function()
			created:Destroy()
			flashes[model] = nil
		end)
		highlight = created
	end
	local h = highlight :: Highlight
	h.FillTransparency = 0.35
	TweenService:Create(h, TweenInfo.new(0.15), { FillTransparency = 1 }):Play()
end

-- Attack visuals ----------------------------------------------------------------------------------------

local function effectPart(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	if shape then
		part.Shape = shape
	end
	part.Parent = fxFolder
	return part
end

local function swing(attacker: Model, target: Model)
	local from = centre(attacker)
	local to = centre(target)
	local direction = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if direction.Magnitude < 0.1 then
		return
	end
	local arc = effectPart("Swing", Vector3.new(4, 0.2, 0.5), Color3.new(1, 1, 1))
	arc.Transparency = 0.3
	local base = CFrame.lookAt(from, from + direction) * CFrame.new(0, 0.5, -2.2)
	arc.CFrame = base * CFrame.Angles(0, math.rad(-50), math.rad(20))
	TweenService:Create(arc, TweenInfo.new(0.15), {
		CFrame = base * CFrame.Angles(0, math.rad(50), math.rad(-20)),
		Transparency = 1,
	}):Play()
	Debris:AddItem(arc, 0.2)
end

local function projectile(attacker: Model, target: Model, style: string)
	local from = centre(attacker) + Vector3.new(0, 0.8, 0)
	local to = centre(target)
	local distance = (to - from).Magnitude
	if distance < 0.5 then
		return
	end
	local part
	if style == "arrow" then
		part = effectPart("Arrow", Vector3.new(0.15, 0.15, 2.2), Color3.fromHex("#C9A45C"))
		part.Material = Enum.Material.Wood
	else
		part = effectPart("Bolt", Vector3.new(0.9, 0.9, 0.9), Theme.Colors.Accent, Enum.PartType.Ball)
		local light = Instance.new("PointLight")
		light.Color = Theme.Colors.Accent
		light.Range = 8
		light.Parent = part
	end
	part.CFrame = CFrame.lookAt(from, to)
	local seconds = math.clamp(distance / 90, 0.08, 0.35)
	TweenService
		:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { CFrame = CFrame.lookAt(to, to + (to - from)) })
		:Play()
	Debris:AddItem(part, seconds + 0.05)
end

-- Telegraphs -----------------------------------------------------------------------------------------------

local function groundDisc(name: string, radius: number, at: CFrame, transparency: number): Part
	local disc = effectPart(name, Vector3.new(0.12, radius * 2, radius * 2), TELEGRAPH_COLOR, Enum.PartType.Cylinder)
	disc.Material = Enum.Material.SmoothPlastic
	disc.Transparency = transparency
	disc.CFrame = at * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90))
	return disc
end

local function telegraph(event: { [string]: any })
	local area = event.cf :: CFrame
	local windup = math.clamp(tonumber(event.t) or 1, 0.2, 5)
	local color = ELEMENT_COLORS[event.el or ""] or TELEGRAPH_COLOR
	local parts: { BasePart } = {}
	local info = TweenInfo.new(windup, Enum.EasingStyle.Linear)

	if event.sh == "circle" then
		local radius = tonumber(event.r) or 8
		local outline = groundDisc("TelegraphOuter", radius, area, 0.7)
		local fill = groundDisc("TelegraphFill", 0.05, area, 0.45)
		outline.Color = color
		fill.Color = color
		TweenService:Create(fill, info, { Size = Vector3.new(0.14, radius * 2, radius * 2) }):Play()
		table.insert(parts, outline)
		table.insert(parts, fill)
	elseif event.sh == "cone" then
		local radius = tonumber(event.r) or 10
		local angle = math.rad(tonumber(event.an) or 90)
		local slices = 9
		for i = 0, slices - 1 do
			local yaw = -angle / 2 + angle * (i + 0.5) / slices
			local width = 2 * radius * math.tan(angle / slices / 2) + 0.2
			local slice = effectPart("TelegraphCone", Vector3.new(width, 0.12, radius), color)
			slice.Material = Enum.Material.SmoothPlastic
			slice.Transparency = 0.7
			slice.CFrame = area * CFrame.Angles(0, -yaw, 0) * CFrame.new(0, 0.15, -radius / 2)
			local fill = effectPart("TelegraphConeFill", Vector3.new(width * 0.95, 0.14, 0.05), color)
			fill.Material = Enum.Material.SmoothPlastic
			fill.Transparency = 0.45
			fill.CFrame = area * CFrame.Angles(0, -yaw, 0) * CFrame.new(0, 0.16, 0)
			TweenService:Create(fill, info, {
				Size = Vector3.new(width * 0.95, 0.14, radius),
				CFrame = area * CFrame.Angles(0, -yaw, 0) * CFrame.new(0, 0.16, -radius / 2),
			}):Play()
			table.insert(parts, slice)
			table.insert(parts, fill)
		end
	elseif event.sh == "ring" then
		-- Ring with a safe centre (bosses): red outer disc filling up, green safe zone in the middle.
		local radius = tonumber(event.r) or 20
		local inner = tonumber(event.ir) or 5
		local outline = groundDisc("TelegraphOuter", radius, area, 0.7)
		local fill = groundDisc("TelegraphFill", inner, area, 0.45)
		local safe = groundDisc("TelegraphSafe", inner, area, 0.35)
		outline.Color = color
		fill.Color = color
		safe.Color = Theme.Colors.Success
		safe.CFrame = safe.CFrame + Vector3.new(0, 0.05, 0)
		TweenService:Create(fill, info, { Size = Vector3.new(0.14, radius * 2, radius * 2) }):Play()
		table.insert(parts, outline)
		table.insert(parts, fill)
		table.insert(parts, safe)
	elseif event.sh == "line" then
		local length = tonumber(event.l) or 15
		local width = tonumber(event.w) or 5
		local outline = effectPart("TelegraphLine", Vector3.new(width, 0.12, length), color)
		outline.Material = Enum.Material.SmoothPlastic
		outline.Transparency = 0.7
		outline.CFrame = area * CFrame.new(0, 0.15, -length / 2)
		local fill = effectPart("TelegraphLineFill", Vector3.new(width * 0.95, 0.14, 0.05), color)
		fill.Material = Enum.Material.SmoothPlastic
		fill.Transparency = 0.45
		fill.CFrame = area * CFrame.new(0, 0.16, 0)
		TweenService:Create(fill, info, {
			Size = Vector3.new(width * 0.95, 0.14, length),
			CFrame = area * CFrame.new(0, 0.16, -length / 2),
		}):Play()
		table.insert(parts, outline)
		table.insert(parts, fill)
	end

	task.delay(windup, function()
		for _, part in parts do
			TweenService:Create(part, TweenInfo.new(0.2), { Transparency = 1 }):Play()
			Debris:AddItem(part, 0.25)
		end
	end)
end

-- Dispatcher ---------------------------------------------------------------------------------------------

local function onDamage(event: { [string]: any })
	local model = findModel(event.e)
	if not model then
		return
	end
	local isMe = model == player.Character
	if event.d then
		if numbersEnabled() then
			floatText(headPosition(model), Text.now("combat.dodge"), Theme.Colors.TextMuted, 22)
		end
		return
	end
	local amount = tonumber(event.a) or 0
	if amount <= 0 then
		return
	end
	flash(model)
	if numbersEnabled() then
		local text = Format.number(amount)
		local color = Color3.new(1, 1, 1)
		local size = 26
		if isMe then
			color = Theme.Colors.DangerHover
		elseif event.c then
			color = Theme.Colors.GoldBright
		end
		if event.c then
			text ..= "!"
			size = 36
		end
		floatText(headPosition(model), text, color, size)
	end
end

local function handle(event: { [string]: any })
	local kind = event.k
	if kind == "dmg" then
		onDamage(event)
	elseif kind == "heal" then
		local model = findModel(event.e)
		if model and numbersEnabled() then
			floatText(headPosition(model), `+{Format.number(tonumber(event.a) or 0)}`, Theme.Colors.Success, 24)
		end
	elseif kind == "atk" then
		local attacker = findModel(event.s)
		local target = findModel(event.t)
		if attacker and target then
			if event.st == "melee" then
				swing(attacker, target)
			else
				projectile(attacker, target, event.st)
			end
			if attacker == player.Character or target == player.Character then
				Sounds.play("hit")
			end
		end
	elseif kind == "tele" then
		telegraph(event)
	elseif kind == "reward" then
		local character = player.Character
		if character then
			local text = Text.now(
				"combat.reward",
				{ exp = Format.number(event.exp or 0), gold = Format.number(event.gold or 0) }
			)
			floatText(headPosition(character) + Vector3.new(0, 1, 0), text, Theme.Colors.Gold, 22, 4)
		end
	end
end

function CombatFxController.Init()
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "Vaelthorn_CombatFx"
	fxFolder.Parent = Workspace
	guiFolder = Instance.new("Folder")
	guiFolder.Name = "Vaelthorn_CombatGui"
	guiFolder.Parent = player:WaitForChild("PlayerGui")
	for _ = 1, 12 do
		table.insert(pool, newBillboard())
	end
end

function CombatFxController.Start()
	Net.On("CombatFx", function(batch: any)
		if type(batch) ~= "table" then
			return
		end
		for _, event in batch do
			if type(event) == "table" then
				local ok = pcall(handle, event)
				if not ok then
					continue
				end
			end
		end
	end)
end

return CombatFxController
