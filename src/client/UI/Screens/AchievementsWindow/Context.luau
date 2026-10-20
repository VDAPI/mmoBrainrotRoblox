--!strict
-- Shared state of the achievements window (S151b): the achievement state read from the replicated save at most every
-- Config.Achievements.listRefresh seconds (the kill counter changes many times a minute), the window's own values
-- (category, filter, range, selection, phone sheet) and the text helpers of the view model (Logic/AchievementView).
-- The window computes no rule of its own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AchData = require(ReplicatedStorage.Shared.Data.Achievements)
local AchievementView = require(ReplicatedStorage.Shared.Logic.AchievementView)
local Achievements = require(ReplicatedStorage.Shared.Logic.Achievements)
local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local State = require(script.Parent.Parent.Parent.State)
local Text = require(script.Parent.Parent.Parent.Text)

type Scope = Fusion.Scope<typeof(Fusion)>

export type Props = {
	Focus: Fusion.Value<string?>, -- the selected achievement (also set by the toast's "View" and the tracker)
	Track: (id: string, on: boolean) -> (),
	SetTitle: (titleId: string) -> (),
	OpenWardrobe: (cosmeticId: string) -> (),
}

export type Ctx = {
	props: Props,
	st: Fusion.Computed<Achievements.State>,
	cat: Fusion.Value<string>,
	filter: Fusion.Value<string>, -- "all" | "open" | "done"
	range: Fusion.Value<string>, -- "all" | "account" | "character"
	selected: Fusion.Value<string?>,
	sheet: Fusion.Value<boolean>, -- phone: the details sheet is open
}

local Context = {}

Context.ROMAN = table.freeze({ "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" })

Context.CAT_GLYPH = table.freeze({
	combat = "⚔",
	bosses = "☠",
	explore = "⌖",
	craft = "⚒",
	social = "☺",
	journey = "✎",
} :: { [string]: string })

Context.REWARD_GLYPH = table.freeze({
	title = "♛",
	cosmetic = "✧",
	shards = "◆",
	shardsPaid = "◇",
	gold = "●",
} :: { [string]: string })

function Context.new(scope: Scope, props: Props): Ctx
	local tick = scope:Value(0)
	local pending = false
	local alive = true
	table.insert(scope, function()
		alive = false
	end)
	local function bump()
		if pending then
			return
		end
		pending = true
		task.delay(Config.Achievements.listRefresh, function()
			pending = false
			if alive then
				tick:set(Fusion.peek(tick) + 1)
			end
		end)
	end
	scope:Observer(State.Value({ "account", "ach" })):onChange(bump)
	scope:Observer(State.Value({ "character", "ach" })):onChange(bump)

	local st = scope:Computed(function(use): Achievements.State
		use(tick)
		return AchievementView.read(State.Get({ "account" }), State.Get({ "character" }))
	end)

	local focus = Fusion.peek(props.Focus)
	local focusDef = if focus then AchData.get(focus) else nil
	local cat = scope:Value(if focusDef then focusDef.cat else AchData.CATEGORIES[1])
	local sheet = scope:Value(focusDef ~= nil)
	-- a "View" while the window is open: its category and (phone) the sheet
	scope:Observer(props.Focus):onChange(function()
		local id = Fusion.peek(props.Focus)
		local def = if id then AchData.get(id) else nil
		if def then
			cat:set(def.cat)
			sheet:set(true)
		end
	end)

	return {
		props = props,
		st = st,
		cat = cat,
		filter = scope:Value("all"),
		range = scope:Value("all"),
		selected = props.Focus,
		sheet = sheet,
	}
end

-- A reward line as text ("Title: {name}", "Dragon Shards: {n}", "already received on this account").
function Context.rewardText(use: Fusion.Use, line: AchievementView.RewardLine): string
	if line.nameKey then
		return Text.get(use, line.key, { name = Text.get(use, line.nameKey) })
	elseif line.n then
		return Text.get(use, line.key, { n = line.n })
	end
	return Text.get(use, line.key)
end

-- The description of a row with its goal ("" for a hidden one).
function Context.desc(use: Fusion.Use, row: AchievementView.Row): string
	return if row.descKey then Text.get(use, row.descKey, { goal = row.goal }) else ""
end

-- "I II III" of a series, the done steps marked (plain text; the current step in brackets).
function Context.stepsText(row: AchievementView.Row): string
	if #row.steps < 2 then
		return ""
	end
	local parts: { string } = {}
	for i, step in row.steps do
		local numeral = Context.ROMAN[i] or tostring(i)
		if step.id == row.id then
			table.insert(parts, `[{numeral}]`)
		elseif step.done then
			table.insert(parts, `{numeral}✓`)
		else
			table.insert(parts, numeral)
		end
	end
	return table.concat(parts, " ")
end

-- The glyphs of a row's reward ("♛ ◆").
function Context.rewardGlyphs(row: AchievementView.Row): string
	local parts: { string } = {}
	for _, line in row.reward do
		local glyph = Context.REWARD_GLYPH[line.kind]
		if glyph then
			table.insert(parts, glyph)
		end
	end
	return table.concat(parts, " ")
end

-- "25 / 100" (the value never above the goal).
function Context.progressText(row: AchievementView.Row): string
	if row.hidden then
		return ""
	end
	return `{math.min(row.value, row.goal)} / {row.goal}`
end

return Context
