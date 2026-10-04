--!strict
-- Founding a guild at the Guild Master (DESIGN §19): name and tag with live validation (Logic/Guild), the
-- cost and level requirement shown red when unmet. The server re-checks everything, filters the text and
-- reserves the name and tag.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Button = require(script.Parent.Parent.Components.Button)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Guild = require(ReplicatedStorage.Shared.Logic.Guild)
local GuildSkills = require(ReplicatedStorage.Shared.Data.GuildSkills)
local Net = require(ReplicatedStorage.Shared.Net)
local Sounds = require(script.Parent.Parent.Sounds)
local State = require(script.Parent.Parent.State)
local Text = require(script.Parent.Parent.Text)
local TextInput = require(script.Parent.Parent.Components.TextInput)
local Theme = require(script.Parent.Parent.Theme)
local Toast = require(script.Parent.Parent.Components.Toast)

type Scope = Fusion.Scope<typeof(Fusion)>

local Rules = GuildSkills.Rules

local function GuildFound(scope: Scope, onDone: () -> ()): Fusion.Child
	local name = scope:Value("")
	local tag = scope:Value("")
	local busy = scope:Value(false)
	local level = State.Value({ "character", "level" })
	local gold = State.Value({ "character", "gold" })

	local nameError = scope:Computed(function(use): string?
		local text = use(name)
		if text == "" then
			return nil
		end
		local ok, err = Guild.validateName(text)
		return if ok then nil else Text.get(use, err :: string, { min = Rules.nameMin, max = Rules.nameMax })
	end)
	local tagError = scope:Computed(function(use): string?
		local text = use(tag)
		if text == "" then
			return nil
		end
		local ok, err = Guild.validateTag(string.upper(text))
		return if ok then nil else Text.get(use, err :: string, { min = Rules.tagMin, max = Rules.tagMax })
	end)
	local levelOk = scope:Computed(function(use): boolean
		return (use(level) or 0) >= Rules.createLevel
	end)
	local goldOk = scope:Computed(function(use): boolean
		return (use(gold) or 0) >= Rules.createCost
	end)
	local canFound = scope:Computed(function(use): boolean
		return not use(busy)
			and use(name) ~= ""
			and use(tag) ~= ""
			and use(nameError) == nil
			and use(tagError) == nil
			and use(levelOk)
			and use(goldOk)
	end)

	local function requirement(
		order: number,
		key: string,
		args: { [string]: any },
		ok: Fusion.Computed<boolean>
	): Instance
		return scope:New("TextLabel")({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 26),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				return `{if use(ok) then "✔" else "✘"}  {Text.get(use, key, args)}`
			end),
			FontFace = Theme.Fonts.BodyMedium,
			TextSize = Theme.TextSize.Body,
			TextColor3 = scope:Computed(function(use): Color3
				return if use(ok) then Theme.Colors.Success else Theme.Colors.Danger
			end),
			TextXAlignment = Enum.TextXAlignment.Left,
		})
	end

	local function found()
		if not Fusion.peek(canFound) then
			return
		end
		busy:set(true)
		task.spawn(function()
			local ok, err = Net.Invoke("GuildCreate", Fusion.peek(name), string.upper(Fusion.peek(tag)))
			busy:set(false)
			if ok then
				Sounds.play("levelUp")
				Toast.push(Text.now("guild.founded.toast", { name = Fusion.peek(name) }), "success")
				onDone()
			else
				Sounds.play("error")
				Toast.push(Text.now(err or "error.internal"), "error")
			end
		end)
	end

	return {
		scope:New("UIListLayout")({ SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }),
		scope:New("TextLabel")({
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 52),
			BackgroundTransparency = 1,
			Text = Text.T(scope, "guild.found.intro"),
			TextWrapped = true,
			FontFace = Theme.Fonts.Body,
			TextSize = Theme.TextSize.Body,
			TextColor3 = Theme.Colors.TextMuted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
		TextInput(scope, {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 74),
			Text = name,
			MaxLength = Rules.nameMax,
			Placeholder = Text.T(scope, "guild.found.name"),
			Error = nameError,
		}),
		TextInput(scope, {
			LayoutOrder = 3,
			Size = UDim2.new(0.5, 0, 0, 74),
			Text = tag,
			MaxLength = Rules.tagMax,
			Placeholder = Text.T(scope, "guild.found.tag"),
			Error = tagError,
		}),
		scope:New("TextLabel")({
			LayoutOrder = 4,
			Size = UDim2.new(1, 0, 0, 30),
			BackgroundTransparency = 1,
			Text = scope:Computed(function(use): string
				local t = string.upper(use(tag))
				local n = use(name)
				return if t ~= "" and n ~= "" then Text.get(use, "guild.found.preview", { tag = t, name = n }) else ""
			end),
			FontFace = Theme.Fonts.Heading,
			TextSize = Theme.TextSize.Large,
			TextColor3 = Theme.Colors.GoldBright,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		requirement(5, "guild.found.level", { level = Rules.createLevel }, levelOk),
		requirement(6, "guild.found.cost", { cost = Format.number(Rules.createCost) }, goldOk),
		Button(scope, {
			LayoutOrder = 7,
			Size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeight),
			Variant = "primary",
			Text = Text.T(scope, "guild.found.button"),
			Disabled = scope:Computed(function(use): boolean
				return not use(canFound)
			end),
			OnClick = found,
		}),
	}
end

return GuildFound
