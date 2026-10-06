--!strict
-- Dev panel, "Character" tab (S23): current values on top, level / experience / gold / shards / points, resets,
-- switches (invulnerable, infinite resources, no cooldowns, speed), healing and the test gear set.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Rarities = require(ReplicatedStorage.Shared.Data.Rarities)
local NumberInput = require(script.Parent.Parent.Parent.Components.NumberInput)
local Select = require(script.Parent.Parent.Parent.Components.Select)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)
local Toggle = require(script.Parent.Parent.Parent.Components.Toggle)

local Dev = require(script.Parent.Dev)

local function Character(s: Dev.Scope): Instance
	local level = State.Value({ "character", "level" })
	local gold = State.Value({ "character", "gold" })
	local shards = State.Value({ "account", "dragonShards" })
	local hp = State.Value({ "character", "hp" })
	local mana = State.Value({ "character", "mana" })
	local statPoints = State.Value({ "character", "statPoints" })
	local skillPoints = State.Value({ "character", "skillPoints" })

	local levelInput = s:Value(Fusion.peek(level) or 1)
	local expInput = s:Value(1000)
	local goldInput = s:Value(10000)
	local shardsInput = s:Value(1000)
	local statInput = s:Value(10)
	local skillInput = s:Value(5)
	local speedInput = s:Value(40)
	local presetLevel = s:Value(50)
	local presetRarity = s:Value("4" :: string?)
	local presetUp = s:Value(7)
	local god = s:Value(false)
	local infinite = s:Value(false)
	local noCooldowns = s:Value(false)

	local rarityOptions = {}
	for r = 1, 5 do
		local def = Rarities.get(r)
		table.insert(rarityOptions, { value = tostring(r), label = if def then Text.now(def.nameKey) else tostring(r) })
	end

	local function num(v: Fusion.Value<number>): string
		return tostring(Fusion.peek(v))
	end

	return Dev.column(s, {
		s:New("TextLabel")({
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 24),
			BackgroundTransparency = 1,
			Text = s:Computed(function(use): string
				return Text.get(use, "dev.char.state", {
					level = use(level) or "-",
					gold = use(gold) or 0,
					shards = use(shards) or 0,
					hp = use(hp) or 0,
					mana = use(mana) or 0,
					stat = use(statPoints) or 0,
					skill = use(skillPoints) or 0,
				})
			end),
			FontFace = Theme.Fonts.BodyBold,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Colors.GoldBright,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Dev.header(s, 2, "dev.char.progress"),
		Dev.row(s, 3, Text.T(s, "dev.char.level"), {
			NumberInput(s, { Value = levelInput, Min = 1, Max = 100 }),
			Dev.button(s, Text.T(s, "dev.set"), function()
				Dev.run("lvl", { num(levelInput) })
			end),
			Dev.button(s, "+1", function()
				Dev.run("lvl", { tostring(math.min(100, (Fusion.peek(level) or 1) + 1)) })
			end, 60),
			Dev.button(s, "+10", function()
				Dev.run("lvl", { tostring(math.min(100, (Fusion.peek(level) or 1) + 10)) })
			end, 60),
		}),
		Dev.row(s, 4, Text.T(s, "dev.char.exp"), {
			NumberInput(s, { Value = expInput, Min = 1, Max = 1e9, Step = 1000 }),
			Dev.button(s, Text.T(s, "dev.give"), function()
				Dev.run("exp", { num(expInput) })
			end),
		}),
		Dev.row(s, 5, Text.T(s, "dev.char.gold"), {
			NumberInput(s, { Value = goldInput, Min = 0, Max = 1e12, Step = 1000 }),
			Dev.button(s, Text.T(s, "dev.set"), function()
				Dev.run("setgold", { num(goldInput) })
			end),
			Dev.button(s, Text.T(s, "dev.add"), function()
				Dev.run("gold", { num(goldInput) })
			end),
		}),
		Dev.row(s, 6, Text.T(s, "dev.char.shards"), {
			NumberInput(s, { Value = shardsInput, Min = 0, Max = 1e12, Step = 100 }),
			Dev.button(s, Text.T(s, "dev.set"), function()
				Dev.run("setshards", { num(shardsInput) })
			end),
			Dev.button(s, Text.T(s, "dev.add"), function()
				Dev.run("shards", { num(shardsInput) })
			end),
		}),
		Dev.row(s, 7, Text.T(s, "dev.char.statPoints"), {
			NumberInput(s, { Value = statInput, Min = 0, Max = 100000 }),
			Dev.button(s, Text.T(s, "dev.set"), function()
				Dev.run("statpoints", { num(statInput) })
			end),
		}),
		Dev.row(s, 8, Text.T(s, "dev.char.skillPoints"), {
			NumberInput(s, { Value = skillInput, Min = 1, Max = 1000 }),
			Dev.button(s, Text.T(s, "dev.add"), function()
				Dev.run("skillpoints", { num(skillInput) })
			end),
		}),
		Dev.row(s, 9, nil, {
			Dev.button(s, Text.T(s, "dev.char.resetStats"), function()
				Dev.run("stats", { "reset" })
			end, 170),
			Dev.button(s, Text.T(s, "dev.char.resetSkills"), function()
				Dev.run("skills", { "reset" })
			end, 170),
			Dev.button(s, Text.T(s, "dev.char.allSkills"), function()
				Dev.run("skills", { "max" })
			end, 170),
			Dev.button(s, Text.T(s, "dev.char.heal"), function()
				Dev.run("heal")
			end, 120),
		}),
		Dev.header(s, 10, "dev.char.switches"),
		Dev.row(s, 11, nil, {
			Toggle(s, {
				Value = god,
				Label = Text.T(s, "dev.char.god"),
				OnChange = function()
					Dev.run("god")
				end,
			}),
			Toggle(s, {
				Value = infinite,
				Label = Text.T(s, "dev.char.infinite"),
				OnChange = function(on: boolean)
					Dev.run("res", { if on then "inf" else "off" })
				end,
			}),
			Toggle(s, {
				Value = noCooldowns,
				Label = Text.T(s, "dev.char.noCooldowns"),
				OnChange = function(on: boolean)
					Dev.run("cd", { if on then "off" else "on" })
				end,
			}),
		}),
		Dev.row(s, 12, Text.T(s, "dev.char.speed"), {
			NumberInput(s, { Value = speedInput, Min = 1, Max = 300, Step = 5 }),
			Dev.button(s, Text.T(s, "dev.set"), function()
				Dev.run("speed", { num(speedInput) })
			end),
			Dev.button(s, Text.T(s, "dev.off"), function()
				Dev.run("speed", { "off" })
			end),
		}),
		Dev.header(s, 13, "dev.char.preset"),
		Dev.row(s, 14, Text.T(s, "dev.char.presetHint"), {
			NumberInput(s, { Value = presetLevel, Min = 1, Max = 100, Step = 5 }),
			Select(s, { Options = rarityOptions, Selected = presetRarity, Width = 150, ListHeight = 180 }),
			NumberInput(s, { Value = presetUp, Min = 0, Max = 9, Size = UDim2.fromOffset(130, Theme.Size.MinTouch) }),
			Dev.button(s, Text.T(s, "dev.char.presetRun"), function()
				Dev.run("preset", { num(presetLevel), Fusion.peek(presetRarity) or "4", num(presetUp) })
			end, 160),
		}),
		Dev.header(s, 15, "dev.allCommands"),
		Dev.commandRows(s, 16, { "character" }) :: any,
	})
end

return Character
