--!strict
-- Forge window (DESIGN §6–§8): Crafting / Upgrading / Dismantling tabs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Craft = require(script.Craft)
local Dismantle = require(script.Dismantle)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Upgrade = require(script.Upgrade)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	UpgradeTarget: Fusion.Value<Upgrade.Target?>,
	ShowModal: (spec: any) -> (),
	-- Tab to open ("upgrade" after dropping an item on the anvil).
	Tab: Fusion.Value<string>,
}

local function BlacksmithWindow(scope: Scope, props: Props): Fusion.Child
	local content = scope:Computed(function(use, s: Scope): Instance
		local tab = use(props.Tab)
		if tab == "upgrade" then
			return Upgrade(s, { Target = props.UpgradeTarget })
		elseif tab == "dismantle" then
			return Dismantle(s, props.ShowModal)
		end
		return Craft(s)
	end)
	return {
		Tabs(scope, {
			Selected = props.Tab,
			Tabs = {
				{ id = "craft", label = Text.T(scope, "smith.tab.craft") },
				{ id = "upgrade", label = Text.T(scope, "smith.tab.upgrade") },
				{ id = "dismantle", label = Text.T(scope, "smith.tab.dismantle") },
			},
		}),
		scope:New("Frame")({
			Name = "Content",
			Position = UDim2.fromOffset(0, 52),
			Size = UDim2.new(1, 0, 1, -52),
			BackgroundTransparency = 1,
			[Children] = content :: any,
		}),
	}
end

return BlacksmithWindow
