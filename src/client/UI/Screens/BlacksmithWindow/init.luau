--!strict
-- Forge window (DESIGN §6–§8): Crafting / Upgrading / Dismantling tabs; S134j: Transmute (bonus reroll, §6a); S154:
-- Appearance (item looks, §6b); S160k: Effect ("Change effect" of a Legendary / Mythic skill effect, §6a).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Craft = require(script.Craft)
local Dismantle = require(script.Dismantle)
local Effect = require(script.Effect)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Reroll = require(script.Reroll)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Transmog = require(script.Transmog)
local Upgrade = require(script.Upgrade)

local Children = Fusion.Children

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	UpgradeTarget: Fusion.Value<Upgrade.Target?>,
	-- S134j: the Transmute tab's item (its own target; dropping on that tab's anvil sets it)
	RerollTarget: Fusion.Value<Upgrade.Target?>,
	-- S154: the Appearance tab's item (its own target; dropping on that tab's anvil sets it)
	TransmogTarget: Fusion.Value<Upgrade.Target?>,
	-- S160k: the Effect tab's item (its own target; dropping on that tab's anvil sets it)
	EffectTarget: Fusion.Value<Upgrade.Target?>,
	ShowModal: (spec: any) -> (),
	-- Tab to open ("upgrade" after dropping an item on the anvil).
	Tab: Fusion.Value<string>,
}

local function BlacksmithWindow(scope: Scope, props: Props): Fusion.Child
	local content = scope:Computed(function(use, s: Scope): Instance
		local tab = use(props.Tab)
		if tab == "upgrade" then
			return Upgrade(s, { Target = props.UpgradeTarget })
		elseif tab == "reroll" then
			return Reroll(s, { Target = props.RerollTarget, ShowModal = props.ShowModal })
		elseif tab == "effect" then
			return Effect(s, { Target = props.EffectTarget, ShowModal = props.ShowModal })
		elseif tab == "transmog" then
			return Transmog(s, { Target = props.TransmogTarget, ShowModal = props.ShowModal })
		elseif tab == "dismantle" then
			return Dismantle(s, props.ShowModal)
		end
		return Craft(s)
	end)
	return {
		Tabs(scope, {
			Selected = props.Tab,
			Scroll = true, -- S154: five tabs, S160k six (a phone scrolls them sideways)
			Tabs = {
				{ id = "craft", label = Text.T(scope, "smith.tab.craft") },
				{ id = "upgrade", label = Text.T(scope, "smith.tab.upgrade") },
				{ id = "reroll", label = Text.T(scope, "smith.tab.reroll") },
				{ id = "effect", label = Text.T(scope, "smith.tab.effect") },
				{ id = "transmog", label = Text.T(scope, "smith.tab.transmog") },
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
