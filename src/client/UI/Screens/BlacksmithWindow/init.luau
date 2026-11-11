--!strict
-- Forge window (DESIGN §6–§8): Crafting / Upgrading / Dismantling tabs; S134j: Transmute (bonus reroll, §6a); S154:
-- Appearance (item looks, §6b); S160k: Effect ("Change effect" of a Legendary / Mythic skill effect, §6a).
-- Adoption stage (UI package D after C, 2026-11-10; owner 2026-11-10: "too much text, things covering each other,
-- nothing folds"): every tab's main actions stand in the window's Footer, pinned under the content outside its scroll
-- ("Ulepsz" under the anvil, the dismantle buttons, the craft filters, the transmute / effect / look buttons), so on a
-- phone they never sit under the comparison, the chance and the Scroll of Protection. A tab gives its view and its
-- footer row (View); the content starts under the scrolling tab strip (Logic/GearLayout.tabsTop(true)).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Craft = require(script.Craft)
local Dismantle = require(script.Dismantle)
local Effect = require(script.Effect)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GearLayout = require(ReplicatedStorage.Shared.Logic.GearLayout)
local Reroll = require(script.Reroll)
local Tabs = require(script.Parent.Parent.Components.Tabs)
local Text = require(script.Parent.Parent.Text)
local Transmog = require(script.Transmog)
local Upgrade = require(script.Upgrade)
local Window = require(script.Parent.Parent.Components.Window)

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

-- A tab's view and the row it puts in the window's footer.
export type View = { View: Instance, Footer: Fusion.Child }

local function BlacksmithWindow(scope: Scope, props: Props): Window.Parts
	local view = scope:Computed(function(use, s: Scope): View
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
	local top = GearLayout.tabsTop(true)
	local content = {
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
			Position = UDim2.fromOffset(0, top),
			Size = UDim2.new(1, 0, 1, -top),
			BackgroundTransparency = 1,
			[Children] = scope:Computed(function(use): Instance
				return use(view).View
			end),
		}),
	}
	return {
		Content = content,
		Footer = scope:Computed(function(use): Fusion.Child
			return use(view).Footer
		end),
	}
end

return BlacksmithWindow
