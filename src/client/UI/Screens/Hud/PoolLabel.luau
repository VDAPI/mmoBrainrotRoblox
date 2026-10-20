--!strict
-- The weapon pool's name over the skill bar (S139, DESIGN-18 §12 F1): when the bar switches to another pool (a weapon
-- change, PathService swaps `barPool`) a small iron plaque "Pool: <name>" shows for SHOW seconds. Nothing on login.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local SkillPools = require(ReplicatedStorage.Shared.Logic.SkillPools)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

local SHOW = 2 -- seconds

local function PoolLabel(scope: Scope, position: Fusion.UsedAs<UDim2>): Instance
	local barPool = State.Value({ "character", "barPool" })
	local classId = State.Value({ "character", "class" })
	local shown = scope:Value(false)
	local generation = 0
	local last: any = Fusion.peek(barPool)
	scope:Observer(barPool):onChange(function()
		local now = Fusion.peek(barPool)
		-- only a switch from one pool to another (not the first value after loading)
		local switched = type(last) == "string" and last ~= "" and type(now) == "string" and now ~= last
		last = now
		if not switched then
			return
		end
		generation += 1
		local mine = generation
		shown:set(true)
		task.delay(SHOW, function()
			if generation == mine then
				shown:set(false)
			end
		end)
	end)
	-- a new character (class) is not a weapon change
	scope:Observer(classId):onChange(function()
		generation += 1
		last = nil
		shown:set(false)
	end)
	return scope:New("TextLabel")({
		Name = "PoolLabel",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = position,
		Size = UDim2.fromOffset(0, Theme.TextSize.Small + 10),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Iron.Surface,
		BackgroundTransparency = Theme.HudAlpha,
		Text = scope:Computed(function(use): string
			local class = use(classId)
			local pool = use(barPool)
			local def = if type(class) == "string" and type(pool) == "string" then SkillPools.def(class, pool) else nil
			return if def then Text.get(use, "skills.toast.pool", { pool = Text.get(use, def.nameKey) }) else ""
		end),
		FontFace = Theme.Fonts.BodyBold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Iron.Heading,
		Visible = shown,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, Theme.Padding.Small),
				PaddingRight = UDim.new(0, Theme.Padding.Small),
			}),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = Theme.Brass.Line,
			}),
		},
	})
end

return PoolLabel
