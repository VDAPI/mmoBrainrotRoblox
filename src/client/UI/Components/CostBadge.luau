--!strict
-- Owner 2026-10-21: the cost of a skill on its slot (Hud/SkillBar, Hud/MobileSkills): a number with a dark outline,
-- blue for mana, yellow for energy (red for health), from props.Cost (SkillController.Cost, the cost the server takes
-- now) through Logic/SkillCostBadge. `Tick` refreshes it (rank, nodes, items, Arcane Charges change it without a state
-- path of their own).
-- Owner 2026-10-21 (Studio, "12 x 12 px, too small"): the number stands on a dark plate edged in the resource's colour,
-- about 17 real pixels tall on any screen (SkillCostBadge.textSize by the UI scale); a bar slot has it half over its
-- top edge (top left), a button of the touch arc on its rim towards the attack button: never over the picture's
-- centre, the cooldown's seconds or the key.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Scale = require(script.Parent.Parent.Scale)
local SkillCostBadge = require(ReplicatedStorage.Shared.Logic.SkillCostBadge)
local Theme = require(script.Parent.Parent.Theme)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	SkillId: Fusion.UsedAs<string?>,
	Cost: (skillId: string) -> (number, string?),
	Tick: Fusion.UsedAs<any>,
	-- the plate's place in the slot (default: a bar slot's, SkillCostBadge.barPlate) and anchor (default: top left)
	Position: Fusion.UsedAs<UDim2>?,
	AnchorPoint: Fusion.UsedAs<Vector2>?,
	-- the number's size (default: by the UI scale, CostBadge.TextSize)
	TextSize: Fusion.UsedAs<number>?,
}

-- Mana and health a touch lighter (towards the HUD text), so the number reads on the dark plate.
local LIGHTEN = { Mana = 0.3, Energy = 0, Hp = 0.2 }

-- The sizes a bar slot's number takes, by the UI scale (SkillCostBadge.textSize).
local SIZES = { Theme.TextSize.Small, Theme.TextSize.Body, Theme.TextSize.Large }

local CostBadge = {}

-- The number's size on a bar slot at the UI scale now (~SkillCostBadge.SCREEN_PX real pixels).
function CostBadge.TextSize(scope: Scope): Fusion.Computed<number>
	return scope:Computed(function(use): number
		return SkillCostBadge.textSize(use(Scale.Value), SIZES)
	end)
end

-- How far a bar's plates stand over the slots at the most (Hud/PoolLabel stands higher by this much).
CostBadge.OVERHANG = SkillCostBadge.overhang(Theme.TextSize.Large)

function CostBadge.new(scope: Scope, props: Props): Instance
	local badge = scope:Computed(function(use): { text: string, color: Color3 }?
		use(props.Tick)
		local id = use(props.SkillId)
		if not id then
			return nil
		end
		local cost, resource = props.Cost(id)
		local text = SkillCostBadge.label(cost, resource)
		local key = if resource then SkillCostBadge.COLORS[resource] else nil
		if not text or not key then
			return nil
		end
		local color = (Theme.Resource :: any)[key] :: Color3
		return { text = text, color = color:Lerp(Theme.Iron.Text, LIGHTEN[key] or 0) }
	end)
	local size: Fusion.UsedAs<number> = props.TextSize or CostBadge.TextSize(scope)
	local color = scope:Computed(function(use): Color3
		local b = use(badge)
		return if b then b.color else Theme.Iron.Text
	end)
	return scope:New("Frame")({
		Name = "Cost",
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Position = props.Position or scope:Computed(function(use): UDim2
			local x, y = SkillCostBadge.barPlate(use(size))
			return UDim2.fromOffset(x, y)
		end),
		Size = scope:Computed(function(use): UDim2
			return UDim2.fromOffset(0, SkillCostBadge.plateHeight(use(size)))
		end),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Iron.Sunken,
		BackgroundTransparency = Theme.BadgeAlpha,
		Visible = scope:Computed(function(use): boolean
			return use(badge) ~= nil
		end),
		ZIndex = 5,
		[Children] = {
			scope:New("UICorner")({ CornerRadius = Theme.Corner.Small }),
			scope:New("UIStroke")({
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Thickness = Theme.Stroke.Thin,
				Color = color,
			}),
			scope:New("UIPadding")({
				PaddingLeft = UDim.new(0, SkillCostBadge.PAD),
				PaddingRight = UDim.new(0, SkillCostBadge.PAD),
			}),
			scope:New("TextLabel")({
				Name = "Number",
				Size = UDim2.fromScale(0, 1),
				AutomaticSize = Enum.AutomaticSize.X,
				BackgroundTransparency = 1,
				Text = scope:Computed(function(use): string
					local b = use(badge)
					return if b then b.text else ""
				end),
				TextColor3 = color,
				TextStrokeColor3 = Theme.Shade,
				TextStrokeTransparency = 0.1,
				FontFace = Theme.Fonts.BodyBold,
				TextSize = size,
				ZIndex = 5,
			}),
		},
	})
end

return CostBadge
