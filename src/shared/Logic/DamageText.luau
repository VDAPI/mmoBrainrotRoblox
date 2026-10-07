--!strict
-- Floating combat numbers (S29): what a "dmg" / "heal" CombatFx event says and how it looks, who may see it
-- (setting "Damage numbers"), and where it flies so numbers of one target do not overlap. Pure: the client
-- (CombatFxController) draws the result.
--
-- Event fields (CombatService): k ("dmg" | "heal"), e (target entity), s (attacker / healer entity), a (amount),
-- c (crit), d (dodged), ab (absorbed by a shield in full), im (immune), dot + el (damage over time and its
-- element), hot (heal over time), sk (skill id).

local DamageNumbers = require("../Data/DamageNumbers")
local Format = require("../Util/Format")
local Locale = require("../Util/Locale")

export type Result = {
	text: string,
	style: string, -- key of DamageNumbers.styles ("none": nothing to draw)
	crit: boolean,
	element: string?, -- DoT ticks: their element (the colour)
	amount: number,
}

export type Mode = "all" | "mine" | "off"

local DamageText = {}

-- Shown before "Absorbed".
DamageText.SHIELD_ICON = "🛡"

-- Damage-over-time effects -> element of their numbers.
local DOT_ELEMENT: { [string]: string } = {
	burn = "fire",
	poison = "poison",
	bleed = "bleed",
}

function DamageText.dotElement(effectKind: string): string
	return DOT_ELEMENT[effectKind] or effectKind
end

local function attackerOf(event: { [string]: any }): string?
	local s = event.s
	if type(s) == "string" then
		return s
	end
	-- S28 events carried the attacker as `by`.
	return if type(event.by) == "string" then event.by else nil
end

-- Formats one event for the viewer whose entity id is `myEntityId` (nil: not in the world).
function DamageText.format(event: { [string]: any }, myEntityId: string?, lang: string?): Result
	local amount = math.max(0, math.floor(tonumber(event.a) or 0))
	local crit = event.c == true
	local target = if type(event.e) == "string" then event.e else nil
	local attacker = attackerOf(event)
	local received = myEntityId ~= nil and target == myEntityId
	local mine = myEntityId ~= nil and attacker == myEntityId

	if event.k == "heal" then
		if amount <= 0 then
			return { text = "", style = "none", crit = false, amount = 0 }
		end
		return {
			text = `+{Format.number(amount)}`,
			style = if event.hot then "hot" else "heal",
			crit = false,
			amount = amount,
		}
	end

	if event.d then
		return { text = Locale.T("combat.dodge", nil, lang), style = "dodge", crit = false, amount = 0 }
	end
	if event.im then
		return { text = Locale.T("combat.immune", nil, lang), style = "immune", crit = false, amount = 0 }
	end
	if event.ab then
		return {
			text = `{DamageText.SHIELD_ICON} {Locale.T("combat.absorbed", nil, lang)}`,
			style = "absorbed",
			crit = false,
			amount = 0,
		}
	end
	if amount <= 0 then
		return { text = "", style = "none", crit = false, amount = 0 }
	end
	local number = Format.number(amount)
	if event.dot then
		return {
			text = number,
			style = "dot",
			crit = false,
			element = if type(event.el) == "string" then event.el else nil,
			amount = amount,
		}
	end
	local base = if received then "received" elseif mine then "mine" else "other"
	if crit then
		return {
			text = Locale.T("combat.crit", { amount = number }, lang),
			style = base .. "Crit",
			crit = true,
			amount = amount,
		}
	end
	return { text = number, style = base, crit = false, amount = amount }
end

-- Text of a number that collected merged hits (fast attacks).
function DamageText.sumText(style: string, sum: number): string
	local number = Format.number(math.max(0, math.floor(sum)))
	return if style == "heal" or style == "hot" then `+{number}` else number
end

-- Effective setting: settings.dmgMode, or the old switch (S01–S28 `dmgNumbers = false` means "off").
function DamageText.mode(settings: { [string]: any }?): Mode
	if type(settings) ~= "table" then
		return "all"
	end
	local mode = settings.dmgMode
	if mode == "all" or mode == "mine" or mode == "off" then
		return mode
	end
	return if settings.dmgNumbers == false then "off" else "all"
end

-- Whether the viewer draws the number of this event under `mode`.
function DamageText.visible(event: { [string]: any }, myEntityId: string?, mode: Mode): boolean
	if mode == "off" then
		return false
	end
	if mode == "all" then
		return true
	end
	if myEntityId == nil then
		return false
	end
	return event.e == myEntityId or attackerOf(event) == myEntityId
end

-- Stacking ----------------------------------------------------------------------------------------------------
-- Every number of a target takes the lowest free slot (slot n starts n * stackStep studs higher), at most
-- maxPerTarget fly at once (the oldest gives way), and above mergeRate numbers per second new hits of a
-- mergeable style add to the newest number of that style.

export type Placement = {
	action: "new" | "merge",
	id: number, -- the new number, or the one that takes the merged hit
	slot: number, -- 0-based
	sum: number, -- merged: the total now shown
	evict: number?, -- new: id of the number that has to vanish first (target full)
}

type Entry = { id: number, slot: number, born: number, style: string, sum: number }
type Target = { entries: { Entry }, times: { number } }

export type Stack = {
	add: (self: Stack, targetId: string, now: number, style: string, amount: number) -> Placement,
	release: (self: Stack, targetId: string, id: number) -> (),
	count: (self: Stack, targetId: string, now: number) -> number,
	clear: (self: Stack) -> (),
}

function DamageText.newStack(config: typeof(DamageNumbers)?): Stack
	local cfg = config or DamageNumbers
	local targets: { [string]: Target } = {}
	local nextId = 0

	local function prune(t: Target, now: number)
		for i = #t.entries, 1, -1 do
			if now - t.entries[i].born >= cfg.lifetime then
				table.remove(t.entries, i)
			end
		end
		for i = #t.times, 1, -1 do
			if now - t.times[i] > cfg.rateWindow then
				table.remove(t.times, i)
			end
		end
	end

	local stack = {} :: Stack

	function stack.add(_self: Stack, targetId: string, now: number, style: string, amount: number): Placement
		local t = targets[targetId]
		if not t then
			t = { entries = {}, times = {} }
			targets[targetId] = t
		end
		prune(t, now)
		table.insert(t.times, now)
		local styleDef = cfg.styles[style]
		if styleDef and styleDef.mergeable and #t.times > cfg.mergeRate then
			local newest: Entry? = nil
			for _, entry in t.entries do
				if
					entry.style == style
					and now - entry.born <= cfg.mergeAge
					and (newest == nil or entry.born > newest.born)
				then
					newest = entry
				end
			end
			if newest then
				newest.sum += amount
				return { action = "merge", id = newest.id, slot = newest.slot, sum = newest.sum }
			end
		end
		local evict: number? = nil
		if #t.entries >= cfg.maxPerTarget then
			local oldestIndex = 1
			for i, entry in t.entries do
				if entry.born < t.entries[oldestIndex].born then
					oldestIndex = i
				end
			end
			evict = t.entries[oldestIndex].id
			table.remove(t.entries, oldestIndex)
		end
		local used: { [number]: boolean } = {}
		for _, entry in t.entries do
			used[entry.slot] = true
		end
		local slot = 0
		while used[slot] do
			slot += 1
		end
		nextId += 1
		table.insert(t.entries, { id = nextId, slot = slot, born = now, style = style, sum = amount })
		return { action = "new", id = nextId, slot = slot, sum = amount, evict = evict }
	end

	function stack.release(_self: Stack, targetId: string, id: number)
		local t = targets[targetId]
		if not t then
			return
		end
		for i, entry in t.entries do
			if entry.id == id then
				table.remove(t.entries, i)
				break
			end
		end
		-- Nothing in the air: forget the target (its rate starts over, which is right when the numbers stopped).
		if #t.entries == 0 then
			targets[targetId] = nil
		end
	end

	function stack.count(_self: Stack, targetId: string, now: number): number
		local t = targets[targetId]
		if not t then
			return 0
		end
		prune(t, now)
		return #t.entries
	end

	function stack.clear(_self: Stack)
		table.clear(targets)
	end

	return stack
end

return DamageText
