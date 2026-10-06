--!strict
-- Dev panel, "Monsters" tab (S23): spawning (search by name and region, variant, level, count), clearing,
-- lists, Elite II, bosses, phases, the AI state of the target and monster stats.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local NumberInput = require(script.Parent.Parent.Parent.Components.NumberInput)
local Select = require(script.Parent.Parent.Parent.Components.Select)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Dev = require(script.Parent.Dev)

local REGIONS = { "meadows", "duskwood", "ashen", "frostpeak" }

local function MonstersTab(s: Dev.Scope): Instance
	local monsterOptions = {}
	for _, def in Monsters.list do
		local region = REGIONS[def.region] or "?"
		table.insert(monsterOptions, {
			value = def.id,
			label = `{Text.now(def.nameKeys.normal)} · {region}{if def.cave then " ⛰" else ""} · {def.levels.min}–{def.levels.max}`,
		})
	end
	local monster = s:Value(nil :: string?)
	local variant = s:Value("0" :: string?)
	local level = s:Value(10)
	local count = s:Value(1)
	local radius = s:Value(100)
	local phase = s:Value(2)
	local statsLevel = s:Value(20)
	local bossOptions = {}
	for _, boss in Bosses.list do
		table.insert(bossOptions, { value = boss.id, label = Text.now(boss.nameKey) })
	end
	local boss = s:Value(nil :: string?)
	local variantOptions = {
		{ value = "0", label = Text.now("dev.variant.normal") },
		{ value = "1", label = Text.now("dev.variant.elite") },
		{ value = "2", label = Text.now("dev.variant.elite2") },
	}

	local function spawnMany()
		local id = Fusion.peek(monster)
		if not id then
			return
		end
		local n = math.clamp(Fusion.peek(count), 1, 10)
		local args = { id, Fusion.peek(variant) or "0", tostring(Fusion.peek(level)) }
		local i = 0
		local function nextOne()
			i += 1
			if i > n then
				return
			end
			Dev.run("spawn", args, function()
				task.delay(0.2, nextOne)
			end)
		end
		nextOne()
	end

	return Dev.column(s, {
		Dev.header(s, 1, "dev.mon.spawn"),
		Dev.row(s, 2, nil, {
			Select(
				s,
				{ Options = monsterOptions, Selected = monster, Width = 320, Placeholder = Text.now("dev.mon.pick") }
			),
			Select(s, { Options = variantOptions, Selected = variant, Width = 150, ListHeight = 120 }),
		}),
		Dev.row(s, 3, Text.T(s, "dev.mon.levelCount"), {
			NumberInput(s, { Value = level, Min = 1, Max = 100 }),
			NumberInput(s, { Value = count, Min = 1, Max = 10, Size = UDim2.fromOffset(130, Theme.Size.MinTouch) }),
			Dev.button(s, Text.T(s, "dev.mon.spawnRun"), spawnMany, 150),
		}),
		Dev.row(s, 4, Text.T(s, "dev.mon.killall"), {
			NumberInput(s, { Value = radius, Min = 1, Max = 2000, Step = 25 }),
			Dev.button(s, "▶", function()
				Dev.run("killall", { tostring(Fusion.peek(radius)) })
			end, 60, true),
		}),
		Dev.header(s, 5, "dev.mon.info"),
		Dev.row(s, 6, nil, {
			Dev.button(s, "/monsters", function()
				Dev.run("monsters")
			end, 130),
			Dev.button(s, "/groups", function()
				Dev.run("groups")
			end, 120),
			Dev.button(s, "/leash", function()
				Dev.run("leash")
			end, 110),
			Dev.button(s, "/e2 spawn", function()
				Dev.run("e2", { "spawn" })
			end, 130),
			Dev.button(s, "/e2timer", function()
				Dev.run("e2timer")
			end, 120),
		}),
		Dev.row(s, 7, Text.T(s, "dev.mon.stats"), {
			NumberInput(s, { Value = statsLevel, Min = 1, Max = 100 }),
			Dev.button(s, "/mstats", function()
				Dev.run("mstats", { tostring(Fusion.peek(statsLevel)) })
			end, 120),
		}),
		Dev.header(s, 8, "dev.mon.bosses"),
		Dev.row(s, 9, nil, {
			Select(s, { Options = bossOptions, Selected = boss, Width = 220 }),
			Dev.button(s, Text.T(s, "dev.mon.bossSpawn"), function()
				local id = Fusion.peek(boss)
				if id then
					Dev.run("boss", { "spawn", id })
				end
			end, 150),
			Dev.button(s, Text.T(s, "dev.mon.bossReset"), function()
				Dev.run("boss", { "reset" })
			end, 150),
		}),
		Dev.row(s, 10, Text.T(s, "dev.mon.phase"), {
			NumberInput(s, { Value = phase, Min = 1, Max = 3, Size = UDim2.fromOffset(130, Theme.Size.MinTouch) }),
			Dev.button(s, "▶", function()
				Dev.run("phase", { tostring(Fusion.peek(phase)) })
			end, 60),
		}),
		Dev.header(s, 11, "dev.allCommands"),
		Dev.commandRows(s, 12, { "monsters" }) :: any,
	})
end

return MonstersTab
