--!strict
-- Owner 2026-10-21: the cost of a skill in the top-left corner of its slot (Hud/SkillBar, Hud/MobileSkills): a small
-- number with a dark outline, blue for mana, yellow for energy (red for health), from props.Cost (SkillController.Cost,
-- the cost the server takes now) through Logic/SkillCostBadge. `Tick` refreshes it (rank, nodes, items, Arcane Charges
-- change it without a state path of their own).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local SkillCostBadge = require(ReplicatedStorage.Shared.Logic.SkillCostBadge)
local Theme = require(script.Parent.Parent.Theme)

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	SkillId: Fusion.UsedAs<string?>,
	Cost: (skillId: string) -> (number, string?),
	Tick: Fusion.UsedAs<any>,
	Position: Fusion.UsedAs<UDim2>?,
	TextSize: number?,
}

-- Mana and health a touch lighter (towards the HUD text), so the number reads on the dark slot.
local LIGHTEN = { Mana = 0.3, Energy = 0, Hp = 0.2 }

local function CostBadge(scope: Scope, props: Props): Instance
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
	return scope:New("TextLabel")({
		Name = "Cost",
		Position = props.Position or UDim2.fromOffset(3, 1),
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Text = scope:Computed(function(use): string
			local b = use(badge)
			return if b then b.text else ""
		end),
		TextColor3 = scope:Computed(function(use): Color3
			local b = use(badge)
			return if b then b.color else Theme.Iron.Text
		end),
		TextStrokeColor3 = Theme.Shade,
		TextStrokeTransparency = 0.1,
		FontFace = Theme.Fonts.BodyBold,
		TextSize = props.TextSize or Theme.TextSize.Caption,
		TextXAlignment = Enum.TextXAlignment.Left,
		Visible = scope:Computed(function(use): boolean
			return use(badge) ~= nil
		end),
		ZIndex = 5,
	})
end

return CostBadge
