--!strict
-- Dev panel, "Economy & community" tab (S23): blessings, cosmetics, test passes, premium, mail, auctions, guild,
-- trade test, party loot and moving to / bringing other players.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Blessings = require(ReplicatedStorage.Shared.Data.Blessings)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local NumberInput = require(script.Parent.Parent.Parent.Components.NumberInput)
local Products = require(ReplicatedStorage.Shared.Data.Products)
local Select = require(script.Parent.Parent.Parent.Components.Select)
local Text = require(script.Parent.Parent.Parent.Text)
local Theme = require(script.Parent.Parent.Parent.Theme)

local Dev = require(script.Parent.Dev)

local function Economy(s: Dev.Scope): Instance
	local blessingOptions = {}
	for _, def in Blessings.list do
		table.insert(blessingOptions, { value = def.id, label = `{Text.now(def.nameKey)} ({def.id})` })
	end
	local blessing = s:Value(nil :: string?)
	local mailGold = s:Value(1000)
	local treasury = s:Value(10000)
	local bots = s:Value(5)
	local partyCount = s:Value(3)

	local passRows = {}
	for i, pass in Products.passes do
		table.insert(
			passRows,
			Dev.row(s, 10 + i, `{pass.icon} {Text.now(`premium.pass.{pass.key}`)}`, {
				Dev.button(s, "on", function()
					Dev.run("pass", { pass.key, "on" })
				end, 70),
				Dev.button(s, "off", function()
					Dev.run("pass", { pass.key, "off" })
				end, 70),
				Dev.button(s, Text.T(s, "dev.eco.premium"), function()
					Dev.run("premium", { "grant", pass.key })
				end, 150),
			})
		)
	end

	local players = s:Value({} :: { { value: string, label: string } })
	local function refreshPlayers()
		local list = {}
		for _, other in Players:GetPlayers() do
			if other ~= Players.LocalPlayer then
				table.insert(list, { value = other.Name, label = `{other.DisplayName} (@{other.Name})` })
			end
		end
		players:set(list)
	end
	refreshPlayers()
	table.insert(s, Players.PlayerAdded:Connect(refreshPlayers))
	table.insert(
		s,
		Players.PlayerRemoving:Connect(function()
			task.defer(refreshPlayers)
		end)
	)
	local other = s:Value(nil :: string?)

	return Dev.column(s, {
		Dev.header(s, 1, "dev.eco.blessings"),
		Dev.row(s, 2, nil, {
			Select(s, { Options = blessingOptions, Selected = blessing, Width = 300 }),
			Dev.button(s, Text.T(s, "dev.give"), function()
				local id = Fusion.peek(blessing)
				if id then
					Dev.run("bless", { id })
				end
			end),
			Dev.button(s, Text.T(s, "dev.eco.cosmetics"), function()
				Dev.run("cosmetic", { "all" })
			end, 200),
		}),
		Dev.header(s, 3, "dev.eco.passes"),
		passRows :: any,
		Dev.header(s, 20, "dev.eco.mail"),
		Dev.row(s, 21, Text.T(s, "dev.eco.mailGold"), {
			NumberInput(s, { Value = mailGold, Min = 1, Max = 1e9, Step = 1000 }),
			Dev.button(s, "▶", function()
				Dev.run("mail", { "gold", tostring(Fusion.peek(mailGold)) })
			end, 60),
		}),
		Dev.row(s, 22, Text.T(s, "dev.eco.auction"), {
			Dev.button(s, "list", function()
				Dev.run("auction", { "list" })
			end, 90),
			Dev.button(s, "expireall", function()
				Dev.run("auction", { "expireall" })
			end, 120, true),
		}),
		Dev.header(s, 23, "dev.eco.guild"),
		Dev.row(s, 24, nil, {
			Dev.button(s, "info", function()
				Dev.run("guild", { "info" })
			end, 80),
			NumberInput(s, { Value = treasury, Min = 0, Max = 1e9, Step = 1000 }),
			Dev.button(s, Text.T(s, "dev.eco.treasury"), function()
				Dev.run("guild", { "treasury", tostring(Fusion.peek(treasury)) })
			end, 140),
			Dev.button(s, Text.T(s, "dev.eco.guildSkills"), function()
				Dev.run("guild", { "skills", "max" })
			end, 160),
		}),
		Dev.row(s, 25, nil, {
			NumberInput(s, { Value = bots, Min = 1, Max = 40 }),
			Dev.button(s, Text.T(s, "dev.eco.bots"), function()
				Dev.run("guild", { "bots", tostring(Fusion.peek(bots)) })
			end, 140),
			Dev.button(s, Text.T(s, "dev.eco.disband"), function()
				Dev.run("guild", { "disband" })
			end, 140, true),
		}),
		Dev.header(s, 26, "dev.eco.social"),
		Dev.row(s, 27, nil, {
			Dev.button(s, Text.T(s, "dev.eco.trade"), function()
				Dev.run("tradetest")
			end, 160),
			NumberInput(s, { Value = partyCount, Min = 1, Max = 5, Size = UDim2.fromOffset(130, Theme.Size.MinTouch) }),
			Dev.button(s, Text.T(s, "dev.eco.partyloot"), function()
				Dev.run("partyloot", { tostring(Fusion.peek(partyCount)) })
			end, 160),
		}),
		Dev.row(s, 28, Text.T(s, "dev.eco.player"), {
			Select(s, { Options = players, Selected = other, Width = 260, Placeholder = Text.now("dev.eco.nobody") }),
			Dev.button(s, "/goto", function()
				local name = Fusion.peek(other)
				if name then
					Dev.run("goto", { name })
				end
			end, 90),
			Dev.button(s, "/bring", function()
				local name = Fusion.peek(other)
				if name then
					Dev.run("bring", { name })
				end
			end, 90),
		}),
		Dev.header(s, 29, "dev.allCommands"),
		Dev.commandRows(s, 30, { "economy", "guild" }) :: any,
	})
end

return Economy
