--!strict
-- UI plan package B (owner 2026-11-10: "too much text, things covering each other, nothing folds"): one queue for the
-- client's messages (Logic/NoticeQueue) with a fake clock, and where they stand (Logic/TopBand.slots, the plan's L3 and
-- L6): on the plan's PC screens, tablets and phones, under Roblox's top bar of 0, 36 and 58 px, in the HUD's states,
-- with no window and with windows of 560 x 520, 900 x 620 and 1080 x 700 centred and dragged to the top (and a phone's
-- full-screen window). With a window open a message stands over it where it fits, else under its title bar, never on
-- it (owner 2026-10-31, question UI 8).
-- Review 2026-11-10: the placement builds its contexts the way the client does (TopBand.context from the Toasts
-- layer's real size, the scale, the top bar and the HUD's boss bar, arena panel and party), with a phone's dungeon boss
-- bar, the PC party frames and the arena's return panel; an alert goes at its deadline and a blow to dodge goes first;
-- the arena's offer takes the prompt's place; a modal dialog keeps the messages off.
-- Final UI review 2026-11-10: the death screen's content keeps the messages off as a dialog does, and what waits keeps
-- its time while it shows (the killer's toast of a PvP death showed under it and dropped unseen); the legendary card,
-- the only way to the reveal, stands 20 s and waits ten minutes for its place.
-- Seams 2026-11-11: the legendary card's item gets no pickup toast beside it (LootController) and no better-item card
-- after it (LootComfortController hears the pickup from LootController, with the item the card names).

local fs = require("@lune/fs")

local HudStack = require("../src/shared/Logic/HudStack")
local HudZones = require("../src/shared/Logic/HudZones")
local NoticeQueue = require("../src/shared/Logic/NoticeQueue")
local PhoneHud = require("../src/shared/Logic/PhoneHud")
local T = require("./Test")
local TopBand = require("../src/shared/Logic/TopBand")

type Entry = NoticeQueue.Entry
type Queue = NoticeQueue.Queue
type Rect = TopBand.Rect

-- Runs the queue from `from` to `to` in steps of `step` seconds; calls `each(now, shown)` after every update.
local function run(
	q: Queue,
	from: number,
	to: number,
	step: number,
	ctx: NoticeQueue.Context?,
	each: ((number, { Entry }) -> ())?
)
	local now = from
	while now <= to + 1e-9 do
		local shown = NoticeQueue.update(q, now, ctx)
		if each then
			each(now, shown)
		end
		now += step
	end
end

local function ids(list: { Entry }): { number }
	local out = {}
	for _, e in list do
		table.insert(out, e.id)
	end
	return out
end

local function toast(q: Queue, now: number, text: string, tone: string?): Entry?
	return NoticeQueue.push(q, now, { class = "toast", text = text, tone = tone })
end

T.describe("NoticeQueue: the policy (fake clock)", function()
	T.it("keeps the plan's priority order", function()
		T.expect(NoticeQueue.ORDER).toEqual({
			"alert",
			"readyCheck",
			"partyInvite",
			"arenaOffer",
			"invite",
			"bossReward",
			"legendary",
			"fightResult",
			"betterItem",
			"banner",
			"toast",
			"bark",
		})
		local q = NoticeQueue.new("phone")
		-- a phone's pane holds one card or prompt: the ready check beats the better-item card that came first
		local card = NoticeQueue.push(q, 0, { class = "betterItem", seconds = 8 }) :: Entry
		NoticeQueue.update(q, 0)
		T.expect(card.shown).toBe(true)
		local ready = NoticeQueue.push(q, 1, { class = "readyCheck", deadline = 20 }) :: Entry
		NoticeQueue.update(q, 1)
		T.expect(ready.shown).toBe(true)
		T.expect(card.shown).toBe(false)
		-- answered: the card comes back for the time it still had (7 s)
		NoticeQueue.remove(q, ready.id)
		NoticeQueue.update(q, 2)
		T.expect(card.shown).toBe(true)
		T.expect(math.abs((card.left :: number) - 7) < 1e-6).toBe(true)
		-- every class against every lower one
		for i, high in NoticeQueue.ORDER do
			for j = i + 1, #NoticeQueue.ORDER do
				local p = NoticeQueue.new("pc")
				local a = NoticeQueue.push(p, 0, { class = NoticeQueue.ORDER[j] }) :: Entry
				local b = NoticeQueue.push(p, 0, { class = high }) :: Entry
				T.expect({ high, NoticeQueue.ORDER[j], NoticeQueue.before(b, a) })
					.toEqual({ high, NoticeQueue.ORDER[j], true })
			end
		end
	end)

	T.it("shows at most 2 toasts on PC and 1 message on a phone", function()
		local pc = NoticeQueue.new("pc")
		for i = 1, 5 do
			toast(pc, 0, `toast {i}`)
		end
		NoticeQueue.push(pc, 0, { class = "banner", text = "banner", tone = "legendary" })
		NoticeQueue.push(pc, 0, { class = "alert", text = "alert", seconds = 2 })
		run(pc, 0, 20, 0.25, nil, function(_, shown)
			local toasts, banners, alerts = 0, 0, 0
			for _, e in shown do
				toasts += if e.kind == "toast" then 1 else 0
				banners += if e.kind == "banner" then 1 else 0
				alerts += if e.kind == "alert" then 1 else 0
			end
			T.expect(toasts <= 2 and banners <= 1 and alerts <= 1).toBe(true)
		end)
		local phone = NoticeQueue.new("phone")
		toast(phone, 0, "a")
		toast(phone, 0, "b")
		NoticeQueue.push(phone, 0, { class = "banner", text = "c" })
		NoticeQueue.push(phone, 0, { class = "bark", text = "d" })
		NoticeQueue.push(phone, 0, { class = "partyInvite", deadline = 30 })
		NoticeQueue.push(phone, 0, { class = "fightResult", seconds = 10 })
		run(phone, 0, 30, 0.25, nil, function(_, shown)
			local lines, panes = 0, 0
			for _, e in shown do
				local place = NoticeQueue.place("phone", e.kind)
				lines += if place == "line" then 1 else 0
				panes += if place == "pane" then 1 else 0
			end
			T.expect(lines <= 1 and panes <= 1).toBe(true)
		end)
		-- the room the screen has left (Logic/TopBand.slots) lowers a place's capacity
		local tight = NoticeQueue.new("pc")
		toast(tight, 0, "x")
		toast(tight, 0, "y")
		T.expect(#NoticeQueue.update(tight, 0, { room = { toast = 1 } })).toBe(1)
		T.expect(#NoticeQueue.update(tight, 0.1)).toBe(2)
	end)

	T.it("shows a world boss's banner 15 s in red in total, even when something takes its place", function()
		T.expect(NoticeQueue.bannerTone("worldboss.spawn")).toBe("worldboss")
		T.expect(NoticeQueue.bannerTone("loot.announceMythic")).toBe("mythic")
		T.expect(NoticeQueue.bannerTone("loot.announce")).toBe("legendary")
		local phone = NoticeQueue.new("phone")
		local boss =
			NoticeQueue.push(phone, 0, { class = "banner", text = "boss", key = "worldboss.spawn", tone = "worldboss" })
		T.expect((boss :: Entry).seconds).toBe(15)
		local onScreen = 0
		local step = 0.25
		run(phone, 0, 40, step, nil, function(now, shown)
			-- a boss's blow takes the phone's one line at 4 s for 3 s, an error at 10 s
			if math.abs(now - 4) < 1e-9 then
				NoticeQueue.push(phone, now, { class = "alert", text = "Unik!", seconds = 3 })
			elseif math.abs(now - 10) < 1e-9 then
				toast(phone, now, "Za daleko.", "error")
			end
			for _, e in shown do
				if e.id == (boss :: Entry).id then
					onScreen += step
				end
			end
		end)
		T.expect(math.abs(onScreen - 15) <= step + 1e-6).toBe(true)
		T.expect(NoticeQueue.find(phone, (boss :: Entry).id)).toBeNil()
		-- on PC the banner keeps its place: the alert has its own line
		local pc = NoticeQueue.new("pc")
		local wb = NoticeQueue.push(pc, 0, { class = "banner", text = "boss", tone = "worldboss" }) :: Entry
		NoticeQueue.update(pc, 0)
		NoticeQueue.push(pc, 4, { class = "alert", text = "Unik!", seconds = 3 })
		NoticeQueue.update(pc, 4)
		T.expect(wb.shown).toBe(true)
		-- a world boss's banner takes the banner's place from an ordinary one, which then shows its rest
		local p2 = NoticeQueue.new("pc")
		local plain = NoticeQueue.push(p2, 0, { class = "banner", text = "plain" }) :: Entry
		NoticeQueue.update(p2, 0)
		NoticeQueue.update(p2, 2)
		local red = NoticeQueue.push(p2, 2, { class = "banner", text = "red", tone = "worldboss" }) :: Entry
		NoticeQueue.update(p2, 2)
		T.expect(red.shown and not plain.shown).toBe(true)
		NoticeQueue.update(p2, 17)
		T.expect(plain.shown).toBe(true)
		T.expect(math.abs((plain.left :: number) - 3) < 1e-6).toBe(true)
	end)

	T.it("merges the same text within 10 s into one entry with a count", function()
		local q = NoticeQueue.new("pc")
		local first = toast(q, 0, "+12 złota") :: Entry
		NoticeQueue.update(q, 0)
		T.expect(toast(q, 2, "+12 złota")).toBe(first)
		T.expect(toast(q, 3, "+12 złota")).toBe(first)
		T.expect(first.count).toBe(3)
		-- a merged toast shows its whole time again
		NoticeQueue.update(q, 3)
		T.expect(math.abs((first.left :: number) - NoticeQueue.SECONDS.toast) < 1e-6).toBe(true)
		-- another text, or the same one more than 10 s later, is a new entry
		T.expect(toast(q, 3, "+13 złota") ~= first).toBe(true)
		local later = NoticeQueue.new("pc")
		local a = toast(later, 0, "x") :: Entry
		run(later, 0, 11, 0.5)
		T.expect(toast(later, 11, "x") ~= a).toBe(true)
	end)

	T.it("shows the same error at most once per 10 s (combat.levelLock comes every 4 s)", function()
		local q = NoticeQueue.new("pc")
		local cameOn: { number } = {}
		local seen: { [number]: boolean } = {}
		run(q, 0, 40, 0.5, { combat = true }, function(now, shown)
			if now % 4 == 0 then
				NoticeQueue.push(
					q,
					now,
					{ class = "toast", text = "Za wysoki poziom.", key = "combat.levelLock", tone = "error" }
				)
			end
			for _, e in shown do
				if not seen[e.id] then
					seen[e.id] = true
					table.insert(cameOn, now)
				end
			end
		end)
		T.expect(#cameOn >= 3).toBe(true)
		for i = 2, #cameOn do
			T.expect(cameOn[i] - cameOn[i - 1] >= NoticeQueue.ERROR_GAP).toBe(true)
		end
	end)

	T.it("holds the quiet messages in combat, then drops them; errors and alerts never wait", function()
		local q = NoticeQueue.new("pc")
		local info = toast(q, 0, "Zapisano.", "success") :: Entry
		local warn = toast(q, 0, "Plecak prawie pełny.", "warning") :: Entry
		local err = toast(q, 0, "Za daleko.", "error") :: Entry
		local alert = NoticeQueue.push(q, 0, { class = "alert", text = "Unik!" }) :: Entry
		local here = NoticeQueue.push(q, 0, { class = "banner", text = "this server" }) :: Entry
		local away = NoticeQueue.push(q, 0, { class = "banner", text = "other server", crossServer = true }) :: Entry
		local bark = NoticeQueue.push(q, 0, { class = "bark", text = "Hm." }) :: Entry
		local better = NoticeQueue.push(q, 0, { class = "betterItem" }) :: Entry
		local fight = NoticeQueue.push(q, 0, { class = "fightResult", seconds = 40 }) :: Entry
		NoticeQueue.update(q, 0, { combat = true })
		T.expect(err.shown and warn.shown and alert.shown and here.shown and fight.shown).toBe(true)
		T.expect(info.shown or away.shown or bark.shown or better.shown).toBe(false)
		-- combat ends within 10 s: the info toast shows
		NoticeQueue.update(q, 6, { combat = true })
		NoticeQueue.update(q, 7, { combat = false })
		T.expect(info.shown).toBe(true)
		-- a toast held more than 10 s drops; another server's banners, the barks and the better-item card after 30
		local q2 = NoticeQueue.new("pc")
		local held = toast(q2, 0, "Zapisano.") :: Entry
		local away2 = NoticeQueue.push(q2, 0, { class = "banner", text = "other", crossServer = true }) :: Entry
		local bark2 = NoticeQueue.push(q2, 0, { class = "bark", text = "Hm.", wait = 60 }) :: Entry
		local better2 = NoticeQueue.push(q2, 0, { class = "betterItem", wait = 60 }) :: Entry
		run(q2, 0, 11, 0.5, { combat = true })
		T.expect(NoticeQueue.find(q2, held.id)).toBeNil()
		T.expect(NoticeQueue.find(q2, away2.id) ~= nil).toBe(true)
		run(q2, 11.5, 31, 0.5, { combat = true })
		T.expect(NoticeQueue.find(q2, away2.id)).toBeNil()
		T.expect(NoticeQueue.find(q2, bark2.id)).toBeNil()
		T.expect(NoticeQueue.find(q2, better2.id)).toBeNil()
		-- an error takes a toast's place at once, even when two toasts show
		local q3 = NoticeQueue.new("pc")
		local t1 = toast(q3, 0, "one") :: Entry
		local t2 = toast(q3, 0.1, "two") :: Entry
		NoticeQueue.update(q3, 0.1)
		local e3 = toast(q3, 0.2, "three", "error") :: Entry
		NoticeQueue.update(q3, 0.2, { combat = true })
		T.expect(e3.shown and t1.shown and not t2.shown).toBe(true)
		-- a new alert takes the line from an older one at once
		local a1 = NoticeQueue.push(q3, 0.3, { class = "alert", text = "A", seconds = 5 }) :: Entry
		NoticeQueue.update(q3, 0.3)
		local a2 = NoticeQueue.push(q3, 0.4, { class = "alert", text = "B", seconds = 5 }) :: Entry
		NoticeQueue.update(q3, 0.4)
		T.expect(a2.shown and not a1.shown).toBe(true)
	end)

	T.it("review 2026-11-10: an alert goes at its deadline; a blow to dodge goes first among the alerts", function()
		-- the dungeon's countdown, each 3 s on the line and pushed a second apart: what one pushed off never comes back
		local q = NoticeQueue.new("pc")
		local pushed: { Entry } = {}
		local after: { number } = {}
		run(q, 0, 10, 0.25, nil, function(now, shown)
			local i = math.floor(now + 1e-9)
			if math.abs(now - i) < 1e-9 and i <= 3 then
				local text = if i < 3 then tostring(3 - i) else "Walcz!"
				local e = NoticeQueue.push(q, now, { class = "alert", text = text, seconds = 3, deadline = 3 })
				table.insert(pushed, e :: Entry)
				shown = NoticeQueue.update(q, now)
			end
			T.expect(#shown <= 1).toBe(true)
			if #shown == 1 and now < 6 - 1e-9 then
				T.expect(shown[1].id).toBe(pushed[#pushed].id) -- always the newest
			end
			if now >= 6 - 1e-9 then
				for _, e in shown do
					table.insert(after, e.id)
				end
			end
		end)
		T.expect(after).toEqual({})
		-- a blow to dodge keeps the line against a later phase line, which shows only within its own time
		local q2 = NoticeQueue.new("pc")
		local blow = NoticeQueue.push(
			q2,
			0,
			{ class = "alert", text = "Unik!", tone = "danger", seconds = 4, deadline = 4 }
		) :: Entry
		NoticeQueue.update(q2, 0)
		local phase = NoticeQueue.push(q2, 1, { class = "alert", text = "Faza 2", seconds = 5, deadline = 5 }) :: Entry
		NoticeQueue.update(q2, 1)
		T.expect(blow.shown and not phase.shown).toBe(true)
		NoticeQueue.update(q2, 4)
		T.expect(phase.shown).toBe(true)
		NoticeQueue.update(q2, 5.5)
		T.expect(phase.shown).toBe(true)
		NoticeQueue.update(q2, 6)
		T.expect(NoticeQueue.find(q2, phase.id)).toBeNil()
		-- the same alert said again keeps its deadline from the last push
		local q3 = NoticeQueue.new("pc")
		local again = NoticeQueue.push(q3, 0, { class = "alert", text = "Unik!", seconds = 3, deadline = 3 }) :: Entry
		NoticeQueue.update(q3, 0)
		T.expect(NoticeQueue.push(q3, 2, { class = "alert", text = "Unik!", seconds = 3, deadline = 3 })).toBe(again)
		NoticeQueue.update(q3, 4)
		T.expect(again.shown).toBe(true)
		NoticeQueue.update(q3, 5)
		T.expect(NoticeQueue.find(q3, again.id)).toBeNil()
		-- final UI review 2026-11-10 (UI-ZASADY §8): the line draws its text at one size, Title on PC and Body on a
		-- phone, cut at the end (TextScaled made it jump with the text's length on a phone's M line)
		local notify = fs.readFile("src/client/UI/Notify.luau")
		T.expect(string.find(notify, "TextScaled =", 1, true)).toBeNil()
		T.expect(
			string.find(notify, "TextSize = if live.phone then Theme.TextSize.Body else Theme.TextSize.Title,", 1, true)
				~= nil
		).toBe(true)
	end)

	T.it(
		"review 2026-11-10: the arena's offer takes the prompt's place, the invitation waits and comes back",
		function()
			for _, device in { "pc", "phone" } :: { NoticeQueue.Device } do
				local q = NoticeQueue.new(device)
				local party = NoticeQueue.push(q, 0, { class = "partyInvite", deadline = 30 }) :: Entry
				NoticeQueue.update(q, 0)
				T.expect(party.shown).toBe(true)
				-- the offer 5 s later (15 s to answer, silence costs 5 min out of the queue): it shows at once
				local offer = NoticeQueue.push(q, 5, { class = "arenaOffer", deadline = 15, penalty = true }) :: Entry
				NoticeQueue.update(q, 5)
				T.expect({ device, offer.shown, party.shown }).toEqual({ device, true, false })
				-- it beats the ready check too; a plain arena prompt (the tournament's invitation) does not
				local ready = NoticeQueue.push(q, 6, { class = "readyCheck", deadline = 20 }) :: Entry
				NoticeQueue.update(q, 6)
				T.expect(offer.shown and not ready.shown).toBe(true)
				-- answered at 12: the ready check, then the invitation, each within its own deadline
				NoticeQueue.remove(q, offer.id)
				NoticeQueue.update(q, 12)
				T.expect(ready.shown).toBe(true)
				NoticeQueue.remove(q, ready.id)
				NoticeQueue.update(q, 13)
				T.expect(party.shown).toBe(true)
				NoticeQueue.update(q, 30)
				T.expect(NoticeQueue.find(q, party.id)).toBeNil()
			end
			local q = NoticeQueue.new("pc")
			local party = NoticeQueue.push(q, 0, { class = "partyInvite", deadline = 30 }) :: Entry
			NoticeQueue.update(q, 0)
			local tourney = NoticeQueue.push(q, 1, { class = "arenaOffer", deadline = 90 }) :: Entry
			NoticeQueue.update(q, 1)
			T.expect(party.shown and not tourney.shown).toBe(true)
		end
	)

	T.it("final UI review 2026-11-10: what waits keeps its time while the death screen shows", function()
		-- a PvP death on a phone: the killer's toast comes as the screen opens, whose content leaves M no room; the
		-- screen shows 5 s + 0.3 s a level and up to 60 s of choosing
		local dead: NoticeQueue.Context = { paused = true, room = { line = 0, pane = 0 } }
		local q = NoticeQueue.new("phone")
		local killer = toast(q, 0, "Gracz cię pokonał.", "error") :: Entry
		local saved = toast(q, 0, "Zapisano.", "success") :: Entry
		local alert = NoticeQueue.push(q, 0, { class = "alert", text = "Unik!", deadline = 3 }) :: Entry
		local invite = NoticeQueue.push(q, 0, { class = "partyInvite", text = "Ala", deadline = 30 }) :: Entry
		run(q, 0.5, 80, 0.5, dead)
		T.expect(NoticeQueue.find(q, killer.id) ~= nil and not killer.shown).toBe(true)
		T.expect(NoticeQueue.find(q, saved.id) ~= nil).toBe(true)
		-- the deadlines still run: the alert and the invitation went
		T.expect(NoticeQueue.find(q, alert.id)).toBeNil()
		T.expect(NoticeQueue.find(q, invite.id)).toBeNil()
		-- the screen closes: the killer's toast shows its whole time, then the other one
		NoticeQueue.update(q, 80.5)
		T.expect(killer.shown).toBe(true)
		run(q, 81, 84.5, 0.5)
		T.expect(killer.shown).toBe(true)
		NoticeQueue.update(q, 85)
		T.expect(NoticeQueue.find(q, killer.id)).toBeNil()
		T.expect(saved.shown).toBe(true)
		-- without the screen a toast with no room drops after its 20 s; after the screen they count from its close
		local q2 = NoticeQueue.new("phone")
		local lost = toast(q2, 0, "Gracz cię pokonał.", "error") :: Entry
		run(q2, 0.5, 20, 0.5, { room = { line = 0 } })
		T.expect(NoticeQueue.find(q2, lost.id)).toBeNil()
		local q3 = NoticeQueue.new("phone")
		local kept = toast(q3, 0, "Gracz cię pokonał.", "error") :: Entry
		run(q3, 0.5, 60, 0.5, dead)
		run(q3, 60.5, 79.5, 0.5, { room = { line = 0 } })
		T.expect(NoticeQueue.find(q3, kept.id) ~= nil).toBe(true)
		NoticeQueue.update(q3, 80, { room = { line = 0 } })
		T.expect(NoticeQueue.find(q3, kept.id)).toBeNil()
		-- a quiet toast's combat hold waits out the screen too
		local q4 = NoticeQueue.new("pc")
		local quiet = toast(q4, 0, "Zapisano.", "success") :: Entry
		run(q4, 0.5, 30, 0.5, { combat = true, paused = true, room = { toast = 0 } })
		T.expect(NoticeQueue.find(q4, quiet.id) ~= nil).toBe(true)
		NoticeQueue.update(q4, 30.5)
		T.expect(quiet.shown).toBe(true)
	end)

	T.it("final UI review 2026-11-10: the legendary card stands 20 s and waits ten minutes for its place", function()
		-- known item 4: the card is the only way to the reveal (owner question UI 10: from 'Szczegóły' only); it lived
		-- 8 s and dropped after 30 s of waiting while a window met its slot or a higher card held it
		local q = NoticeQueue.new("pc")
		local card = NoticeQueue.push(q, 0, { class = "legendary" }) :: Entry
		T.expect({ card.seconds, card.wait }).toEqual({ 20, 600 })
		T.expect({ card.seconds, card.wait }).toEqual({ NoticeQueue.LEGENDARY.seconds, NoticeQueue.LEGENDARY.wait })
		-- nine minutes with no place (a window over the slot, Logic/TopBand.slots): it still comes, for its 20 s
		run(q, 0, 540, 1, { room = { card = 0 } })
		T.expect(NoticeQueue.find(q, card.id) ~= nil and not card.shown).toBe(true)
		run(q, 541, 560, 0.5)
		T.expect(card.shown).toBe(true)
		NoticeQueue.update(q, 561.5)
		T.expect(NoticeQueue.find(q, card.id)).toBeNil()
		-- never for ever: nothing clears the queue on a character switch
		local q2 = NoticeQueue.new("pc")
		local late = NoticeQueue.push(q2, 0, { class = "legendary" }) :: Entry
		run(q2, 0, 600, 1, { room = { card = 0 } })
		T.expect(NoticeQueue.find(q2, late.id)).toBeNil()
		-- the other cards keep the kind's time and wait; a card's own wait reaches the queue (UI/Notify.card)
		local fight = NoticeQueue.push(q2, 601, { class = "fightResult" }) :: Entry
		T.expect({ fight.seconds, fight.wait }).toEqual({ NoticeQueue.SECONDS.card, NoticeQueue.WAIT.card })
		local own = NoticeQueue.push(q2, 601, { class = "legendary", wait = 5 }) :: Entry
		T.expect(own.wait).toBe(5)
		local notify = fs.readFile("src/client/UI/Notify.luau")
		T.expect(string.find(notify, "wait = card.wait,", 1, true) ~= nil).toBe(true)
	end)

	T.it("seams 2026-11-11: a legendary pickup names its item once, on the card", function()
		-- the pickup toasted '+1 Ostrze Pustki' in the same second as the card 'Legendarny przedmiot! / Ostrze Pustki'
		-- (one home, UI-ZASADY §1); the bag's other items keep their toasts, up to 4
		local loot = fs.readFile("src/client/Controllers/LootController.luau")
		local picked = string.find(loot, "local function onPicked(", 1, true) :: number
		local carded = string.find(loot, "local carded: ItemInstance? = reveal or firstPick", picked, true)
		local toast = string.find(loot, "Toast.push(", picked, true)
		T.expect(carded ~= nil and toast ~= nil and (carded :: number) < (toast :: number)).toBe(true)
		T.expect(string.find(loot, "if shown < 4 and item ~= carded then", picked, true) ~= nil).toBe(true)
		-- the card goes to the same item: the best legendary or mythic piece, else the first valuable drop
		T.expect(
			string.find(loot, "if reveal then\n\t\topenReveal(reveal)\n\telseif firstPick then", picked, true) ~= nil
		)
			.toBe(true)
	end)

	T.it("seams 2026-11-11: the better-item card passes over the item the legendary card names", function()
		-- a legendary or first-drop upgrade also got 'Lepszy przedmiot! / Ostrze Pustki / Załóż', which waited behind the
		-- card and showed when its 'Szczegóły' closed it, under the reveal, still offering 'Załóż' once the reveal had put
		-- the item on: the better-item card hears the pickup from LootController, after the card, with its item
		local loot = fs.readFile("src/client/Controllers/LootController.luau")
		local picked = string.find(loot, "local function onPicked(", 1, true) :: number
		local card = string.find(loot, 'openReveal(firstPick, "reveal.titleFirst")', picked, true)
		local listeners = string.find(loot, "task.spawn(fn, items, carded)", picked, true)
		T.expect(card ~= nil and listeners ~= nil and (card :: number) < (listeners :: number)).toBe(true)
		local comfort = fs.readFile("src/client/Controllers/LootComfortController.luau")
		T.expect(string.find(comfort, 'registry.Get("LootController").OnPicked(onPicked)', 1, true) ~= nil).toBe(true)
		T.expect(string.find(comfort, 'type(item) == "table" and item ~= carded', 1, true) ~= nil).toBe(true)
		-- one handler of the remote on the client: two handlers of one remote run in no set order
		local heard: { string } = {}
		local function walk(dir: string)
			for _, name in fs.readDir(dir) do
				local path = `{dir}/{name}`
				if fs.isDir(path) then
					walk(path)
				elseif string.sub(name, -5) == ".luau" and string.find(fs.readFile(path), '"LootPicked"', 1, true) then
					table.insert(heard, path)
				end
			end
		end
		walk("src/client")
		T.expect(heard).toEqual({ "src/client/Controllers/LootController.luau" })
	end)

	T.it("lets the achievement wait for an open window, and a prompt show until its deadline", function()
		local q = NoticeQueue.new("pc")
		local ach =
			NoticeQueue.push(q, 0, { class = "banner", text = "ach", tone = "achievement", windowWaits = true }) :: Entry
		local other = NoticeQueue.push(q, 0, { class = "toast", text = "toast" }) :: Entry
		NoticeQueue.update(q, 0, { window = true })
		T.expect(ach.shown).toBe(false)
		T.expect(other.shown).toBe(true) -- a toast never waits for a window (owner, question UI 8)
		run(q, 0, 120, 1, { window = true })
		T.expect(NoticeQueue.find(q, ach.id) ~= nil).toBe(false) -- waited too long for a place (WAIT.banner)
		local q2 = NoticeQueue.new("pc")
		local ach2 = NoticeQueue.push(
			q2,
			0,
			{ class = "banner", text = "ach", tone = "achievement", windowWaits = true, wait = math.huge }
		) :: Entry
		run(q2, 0, 200, 1, { window = true })
		T.expect(ach2.shown).toBe(false)
		NoticeQueue.update(q2, 201, { window = false })
		T.expect(ach2.shown).toBe(true)
		local invite = NoticeQueue.push(q2, 0, { class = "partyInvite", deadline = 30 }) :: Entry
		NoticeQueue.update(q2, 202)
		T.expect(NoticeQueue.find(q2, invite.id)).toBeNil() -- its 30 s to answer were over at 30
		local duel = NoticeQueue.push(q2, 300, { class = "invite", deadline = 20 }) :: Entry
		run(q2, 300, 319, 1)
		T.expect(duel.shown).toBe(true)
		NoticeQueue.update(q2, 320)
		T.expect(NoticeQueue.find(q2, duel.id)).toBeNil()
	end)

	T.it("keeps one entry per place in the order of the ladder", function()
		local q = NoticeQueue.new("pc")
		local list = {
			NoticeQueue.push(q, 0, { class = "bark", text = "bark" }),
			toast(q, 0, "toast"),
			NoticeQueue.push(q, 0, { class = "banner", text = "banner" }),
			NoticeQueue.push(q, 0, { class = "betterItem" }),
			NoticeQueue.push(q, 0, { class = "partyInvite", deadline = 30 }),
			NoticeQueue.push(q, 0, { class = "alert", text = "alert" }),
		}
		local shown = NoticeQueue.update(q, 0)
		local want = {}
		for i = #list, 1, -1 do
			table.insert(want, (list[i] :: Entry).id)
		end
		T.expect(ids(shown)).toEqual(want)
	end)
end)

-- Placement ------------------------------------------------------------------------------------------------------

local PC = { { 1920, 1080 }, { 1366, 768 }, { 1280, 720 }, { 1920, 1200 }, { 2560, 1080 }, { 1024, 600 } }
local TABLET = { { 1280, 720 }, { 1024, 768 }, { 1366, 1024 } }
local BARS = { 0, 36, 58 }
local STATES: { HudZones.State } = {
	{},
	{ target = "monster" },
	{ target = "player" },
	{ target = "player", arena = "match" },
	{ target = "player", arena = "return" },
	{ bossBar = true },
	{ bossBar = true, add = true, target = "monster" },
	{ party = 1 },
	{ target = "monster", party = 2 },
	{ bossBar = true, party = 3 },
	{ target = "monster", party = 4, guide = true, waiting = 4, effects = 15 },
}
-- a phone's band: with and without the dungeon boss bar (review 2026-11-10: it took M's place)
local PHONE_STATES: { HudZones.State } = { {}, { bossBar = true } }

type Screen = {
	name: string,
	device: TopBand.Device,
	w: number, -- the Toasts layer
	h: number,
	bar: number, -- virtual pixels
	hudW: number,
	hudH: number,
	-- what the client measures (TopBand.Facts): the Toasts layer's root in real pixels (a phone's safe area), the
	-- UI scale and the top bar in real pixels
	layerW: number,
	layerH: number,
	scale: number,
	topBar: number,
}

local function screens(): { Screen }
	local out: { Screen } = {}
	for _, set in { { device = "pc", sizes = PC }, { device = "tablet", sizes = TABLET } } do
		for _, size in set.sizes do
			for _, bar in BARS do
				local touch = set.device == "tablet"
				local lw, lh, k = HudZones.layer(size[1], size[2], touch, bar)
				table.insert(out, {
					name = `{set.device} {size[1]}x{size[2]} bar {bar}`,
					device = set.device :: TopBand.Device,
					w = size[1] / k,
					h = size[2] / k,
					bar = size[2] / k - lh,
					hudW = lw,
					hudH = lh,
					layerW = size[1],
					layerH = size[2],
					scale = k,
					topBar = bar,
				})
			end
		end
	end
	for _, device in PhoneHud.DEVICES do
		for _, bar in BARS do
			local w, h = PhoneHud.area(device)
			local b = bar / PhoneHud.SCALE
			local i = device.insets
			table.insert(out, {
				name = `phone {device.name} bar {bar}`,
				device = "phone",
				w = w,
				h = h,
				bar = b,
				hudW = w,
				hudH = h - b,
				layerW = device.w - i[1] - i[3],
				layerH = device.h - i[2] - i[4],
				scale = PhoneHud.SCALE,
				topBar = bar,
			})
		end
	end
	return out
end

-- The context the client builds (UI/Notify: TopBand.context) for a screen and the HUD's state.
local function contextOf(s: Screen, state: HudZones.State): TopBand.Context
	return TopBand.context({
		layerW = s.layerW,
		layerH = s.layerH,
		scale = s.scale,
		topBar = s.topBar,
		device = s.device,
		boss = state.bossBar,
		arena = state.arena,
		party = state.party,
	})
end

local function show(r: Rect): string
	return string.format("(%.1f, %.1f)-(%.1f, %.1f)", r.left, r.top, r.right, r.bottom)
end

local function down(r: Rect, dy: number): Rect
	return { left = r.left, top = r.top + dy, right = r.right, bottom = r.bottom + dy }
end

-- The windows of a screen: none, the three PC sizes centred and dragged to the top (header 52), a phone's full screen
-- (header 44).
local function windowSets(s: Screen): { { name: string, list: { TopBand.Window } } }
	local out: { { name: string, list: { TopBand.Window } } } = { { name = "no window", list = {} } }
	if s.device == "phone" then
		table.insert(out, {
			name = "full-screen window",
			list = { { left = 0, top = s.bar, right = s.w, bottom = s.h, header = 44 } },
		})
		return out
	end
	for _, size in { { 560, 520 }, { 900, 620 }, { 1080, 700 } } do
		local ww, wh = math.min(size[1], s.w - 16), math.min(size[2], s.h - s.bar - 16)
		local left = (s.w - ww) / 2
		local centred = (s.h - wh) / 2
		table.insert(out, {
			name = `{size[1]}x{size[2]} centred`,
			list = {
				{
					left = left,
					top = math.max(centred, s.bar + 8),
					right = left + ww,
					bottom = math.max(centred, s.bar + 8) + wh,
					header = 52,
				},
			},
		})
		table.insert(out, {
			name = `{size[1]}x{size[2]} at the top`,
			list = { { left = left, top = s.bar + 8, right = left + ww, bottom = s.bar + 8 + wh, header = 52 } },
		})
	end
	return out
end

-- The band's messages of a device, top down.
local function items(device: TopBand.Device): { TopBand.Item }
	if device == "phone" then
		return { { id = "line", w = 520, h = 70 }, { id = "pane", w = TopBand.PROMPT.w, h = 44 } }
	end
	return {
		{ id = "alert", w = TopBand.ALERT_W, h = HudZones.MESSAGE.alert },
		{ id = "banner", w = TopBand.BANNER_BIG.w, h = TopBand.BANNER_BIG.h },
		{ id = "toast1", w = TopBand.TOAST_WIDTH, h = 52 },
		{ id = "toast2", w = TopBand.TOAST_WIDTH, h = 76 },
		{ id = "prompt", w = TopBand.PROMPT.w, h = TopBand.PROMPT.h },
	}
end

-- The persistent places of the HUD in the whole screen's pixels (PC and tablet: HudZones; phone: the layer's own
-- PhoneHud places but those M shows over: the target's effects, the cast line and the guide bar). Final UI review
-- 2026-11-10: the names follow PhoneHud's (the player menu's '⋯', `targetActions`, stands beside the target, over M,
-- so it stays checked), and the places are the layer's own (the reference phone's could not show M's drift).
local UNDER_M = { targetEffects = true, castBar = true, navBar = true }
local function persistent(s: Screen, state: HudZones.State): { { name: string, rect: Rect } }
	local out = {}
	if s.device == "phone" then
		for name, place in PhoneHud.places(s.hudW, s.hudH) do
			if not UNDER_M[name] and place.h > 0 then
				local r = PhoneHud.rect(place, s.hudW, s.hudH)
				table.insert(out, {
					name = name,
					rect = down({ left = r.left, top = r.top, right = r.right, bottom = r.bottom }, s.bar),
				})
			end
		end
		-- the dungeon boss bar's strip under the target row (it stands over the target's effects, as M does)
		if state.bossBar then
			table.insert(out, { name = "bossBar", rect = down(TopBand.bossBar("phone", s.hudW, s.hudH), s.bar) })
		end
		return out
	end
	local st = table.clone(state)
	st.touch = s.device == "tablet"
	for _, p in HudZones.list(HudZones.pc(s.hudW, s.hudH, st)) do
		-- the card and bark slots hold messages; overlays the player opens are not persistent
		if not p.overlay and p.name ~= "card" and p.name ~= "bark" then
			table.insert(out, { name = p.name, rect = down(p.rect, s.bar) })
		end
	end
	return out
end

local function covered(r: Rect, windows: { TopBand.Window }): boolean
	for _, win in windows do
		if TopBand.meets(r, win) then
			return true
		end
	end
	return false
end

T.describe("TopBand.slots: where the messages stand (L3, L6)", function()
	T.it("no message meets the HUD, a title bar or the tutorial's tile, and all stay under the top bar", function()
		local problems: { string } = {}
		local function bad(text: string)
			if #problems < 30 then
				table.insert(problems, text)
			end
		end
		local placedAny = 0
		for _, s in screens() do
			local states: { HudZones.State } = if s.device == "phone" then PHONE_STATES else STATES
			for _, state in states do
				for _, set in windowSets(s) do
					-- the client's own context (review 2026-11-10: it measured the viewport, not the layer, and
					-- left out the party and the arena's return panel)
					local ctx = contextOf(s, state)
					ctx.windows = set.list
					ctx.items = items(s.device)
					ctx.card = if s.device == "pc" then "fight" else nil
					ctx.bark = s.device == "pc"
					local placed = TopBand.slots(ctx)
					local where = `{s.name}, {set.name}{if state.bossBar then ", boss bar" else ""}`
					local zone = placed.zone
					if s.device ~= "phone" then
						local st = table.clone(state)
						st.touch = s.device == "tablet"
						-- L3: the zone starts GAP under the target band (in the whole screen's pixels)
						local band = HudZones.targetBand(s.hudW, st)
						if
							math.abs(zone.top - math.max(band.bottom + HudStack.GAP + s.bar, s.bar + TopBand.GAP))
							> 1e-6
						then
							bad(`{where}: zone {show(zone)} not GAP under the band {show(band)}`)
						end
					else
						-- M: under the target row (and the boss bar's strip), at least one HUD line tall
						local target = PhoneHud.rect(PhoneHud.PLACES.target, s.hudW, s.hudH)
						local over = if state.bossBar
							then TopBand.bossBar("phone", s.hudW, s.hudH).bottom
							else target.bottom
						if zone.top < over + s.bar + TopBand.PHONE_M.gap - 1e-6 then
							bad(`{where}: M {show(zone)} meets what stands over it (ending {over + s.bar})`)
						end
						if zone.bottom - zone.top < TopBand.PHONE_M.line - 1e-6 then
							bad(`{where}: M {show(zone)} is shorter than a HUD line`)
						end
					end
					local all: { { name: string, rect: Rect } } = {}
					for id, r in placed.rects do
						table.insert(all, { name = id, rect = r })
					end
					if placed.card then
						table.insert(all, { name = "card", rect = placed.card :: Rect })
					end
					if placed.bark then
						table.insert(all, { name = "bark", rect = placed.bark :: Rect })
					end
					-- the first message always has a place
					local first = ctx.items[1].id
					if placed.rects[first] == nil then
						bad(`{where}: no place for the {first}`)
					end
					for _, m in all do
						placedAny += 1
						local r = m.rect
						-- L2: inside the screen, under the top bar + 8
						if
							r.left < -1e-6
							or r.right > s.w + 1e-6
							or r.top < s.bar + TopBand.GAP - 1e-6
							or r.bottom > s.h + 1e-6
						then
							bad(`{where}: {m.name} {show(r)} leaves the screen or touches the top bar`)
						end
						-- never on a window's title bar
						for _, win in set.list do
							local header =
								{ left = win.left, top = win.top, right = win.right, bottom = win.top + win.header }
							if TopBand.meets(r, header) then
								bad(`{where}: {m.name} {show(r)} on a title bar {show(header)}`)
							end
						end
						-- never on the HUD (a part a window covers is out of sight: a message under the title bar may
						-- stand over it)
						for _, p in persistent(s, state) do
							if
								TopBand.meets(r, p.rect)
								and not covered(p.rect, set.list)
								and not covered(r, set.list)
							then
								bad(`{where}: {m.name} {show(r)} on {p.name} {show(p.rect)}`)
							end
						end
						-- with no window, the band's messages stand in the zone (on PC and a tablet the first one may
						-- reach below a zone shorter than itself; a phone's is cut to M)
						if #set.list == 0 and placed.rects[m.name] then
							local outside = r.left < zone.left - 1e-6
								or r.right > zone.right + 1e-6
								or r.top < zone.top - 1e-6
							local low = r.bottom > zone.bottom + 1e-6
								and not (s.device ~= "phone" and m.name == first and r.top == zone.top)
							if outside or low then
								bad(`{where}: {m.name} {show(r)} leaves the zone {show(zone)}`)
							end
						end
					end
				end
			end
		end
		T.expect(placedAny > 1000).toBe(true)
		if #problems > 0 then
			error(table.concat(problems, "\n"))
		end
	end)

	T.it("review 2026-11-10: the client's context is the Toasts layer's own, with the party and the arena", function()
		for _, s in screens() do
			local ctx = contextOf(s, {})
			local same = math.abs(ctx.w - s.w) < 1e-6
				and math.abs(ctx.h - s.h) < 1e-6
				and math.abs(ctx.bar - s.bar) < 1e-6
			T.expect({ s.name, same }).toEqual({ s.name, true })
		end
		-- a phone's safe area, not its viewport: 844 x 390 with its notch is 886 x 436 virtual pixels, not 997 x 461
		local phone = PhoneHud.DEVICES[1]
		local w, h = PhoneHud.area(phone)
		local ctx =
			TopBand.context({ layerW = 750, layerH = 369, scale = PhoneHud.SCALE, topBar = 0, device = "phone" })
		T.expect(math.abs(ctx.w - w) < 1e-6 and math.abs(ctx.h - h) < 1e-6).toBe(true)
		-- the state branch `arenaLive`: the match panel, the way back, nothing
		T.expect(TopBand.arenaState({ match = {} })).toBe("match")
		T.expect(TopBand.arenaState({ returnAt = 1234.5 })).toBe("return")
		T.expect(TopBand.arenaState({ offer = {} })).toBeNil()
		T.expect(TopBand.arenaState(nil)).toBeNil()
		-- the return panel moves the band down as the match panel does
		local facts: TopBand.Facts =
			{ layerW = 1920, layerH = 1080, scale = 1, topBar = 0, device = "pc", arena = "return" }
		local back = TopBand.zone(TopBand.context(facts))
		local band = HudZones.targetBand(1920, { arena = "return" })
		T.expect(back.top).toBe(band.bottom + HudStack.GAP)
		T.expect(
			back.top
				> TopBand.zone(TopBand.context({ layerW = 1920, layerH = 1080, scale = 1, topBar = 0, device = "pc" })).top
		).toBe(true)
		-- the PC bark stands under the party's rows
		for n = 0, 4 do
			local c = TopBand.context({ layerW = 1920, layerH = 1080, scale = 1, topBar = 0, device = "pc", party = n })
			c.bark = true
			local bark = TopBand.slots(c).bark
			T.expect(bark ~= nil).toBe(true)
			local zones = HudZones.pc(1920, 1080, { party = n })
			for i, row in zones.party do
				T.expect({ n, i, TopBand.meets(bark :: Rect, row) }).toEqual({ n, i, false })
			end
		end
	end)

	T.it(
		"review 2026-11-10: a message waits while it would meet a modal dialog; a phone's is never taller than M",
		function()
			local w, h = 1920, 1080
			local zone = TopBand.zone({ w = w, h = h, bar = 0, device = "pc", items = {} })
			local list = items("pc")
			local free = TopBand.slots({ w = w, h = h, bar = 0, device = "pc", items = list })
			-- a dialog over the band's middle: what would meet it waits, the rest keep their places
			local dialog = { left = 660, top = free.rects.toast1.top + 4, right = 1260, bottom = 700 }
			local placed = TopBand.slots({ w = w, h = h, bar = 0, device = "pc", items = list, modals = { dialog } })
			for id, r in placed.rects do
				T.expect({ id, TopBand.meets(r, dialog) }).toEqual({ id, false })
			end
			T.expect(placed.rects.alert ~= nil and placed.rects.toast1 == nil).toBe(true)
			-- the card waits while a dialog covers its slot
			local slot = HudZones.cardSlot(w, h, "fight")
			local card =
				TopBand.slots({ w = w, h = h, bar = 0, device = "pc", items = {}, card = "fight", modals = { slot } })
			T.expect(card.card).toBeNil()
			T.expect(zone.top < dialog.top).toBe(true)
			-- a phone: a line taller than M is cut to M's height
			local pw, ph = PhoneHud.area(PhoneHud.DEVICES[1])
			local bar = 58 / PhoneHud.SCALE
			local ctx: TopBand.Context = {
				w = pw,
				h = ph,
				bar = bar,
				device = "phone",
				hud = { bossBar = true },
				items = { { id = "line", w = 900, h = 90 } },
			}
			local m = TopBand.zone(ctx)
			local r = TopBand.slots(ctx).rects.line
			T.expect(r ~= nil).toBe(true)
			T.expect(math.abs(r.bottom - m.bottom) < 1e-6 and math.abs(r.top - m.top) < 1e-6).toBe(true)
		end
	)

	T.it("final UI review 2026-11-10: no message meets the death screen's content, on any screen", function()
		local problems: { string } = {}
		local states: { HudZones.State } = { {}, { bossBar = true }, { target = "monster", party = 4 } }
		for _, s in screens() do
			-- the content in the HUD's layer (Hud/DeathScreen), moved under the top bar as the Toasts layer sees it
			local death = down(HudZones.death(s.hudW, s.hudH), s.bar)
			if
				death.left < -1e-6
				or death.right > s.w + 1e-6
				or death.top < s.bar - 1e-6
				or death.bottom > s.h + 1e-6
			then
				table.insert(problems, `{s.name}: the death screen {show(death)} leaves the HUD's layer`)
			end
			for _, state in states do
				local ctx = contextOf(s, state)
				ctx.items = items(s.device)
				ctx.card = if s.device == "pc" then "legend" else nil
				ctx.bark = s.device == "pc"
				ctx.modals = { death }
				local placed = TopBand.slots(ctx)
				local all: { [string]: Rect } = table.clone(placed.rects)
				all.card = placed.card
				all.bark = placed.bark
				for id, r in all do
					if TopBand.meets(r, death) then
						table.insert(problems, `{s.name}: the {id} {show(r)} meets the death screen {show(death)}`)
					end
				end
			end
		end
		if #problems > 0 then
			error(table.concat(problems, "\n"))
		end
		-- the client: the screen hands its content over, the band treats it as a dialog and holds what waits
		local screen = fs.readFile("src/client/UI/Screens/Hud/DeathScreen.luau")
		T.expect(string.find(screen, "HudCover.SetDeath(content)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(screen, "HudCover.ClearDeath(content)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(screen, "HudZones.deathScale(size.Y)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(screen, "Size = UDim2.new(DEATH.share, 0, 0, DEATH.h)", 1, true) ~= nil).toBe(true)
		local notify = fs.readFile("src/client/UI/Notify.luau")
		T.expect(string.find(notify, "for _, r in Fusion.peek(HudCover.Death) do", 1, true) ~= nil).toBe(true)
		T.expect(string.find(notify, "paused = Fusion.peek(HudCover.Dead),", 1, true) ~= nil).toBe(true)
	end)

	T.it("puts a message over a window where it fits there, else under its title bar", function()
		local w, h, bar = 1920, 1080, 58
		local hud: HudZones.State = { target = "monster" }
		local zone = TopBand.zone({ w = w, h = h, bar = bar, device = "pc", hud = hud, items = {} })
		local item = { { id = "toast1", w = TopBand.TOAST_WIDTH, h = 52 } }
		-- the strip over the window holds the toast: it stands there
		local low: TopBand.Window =
			{ left = 660, top = zone.top + 52 + TopBand.GAP, right = 1260, bottom = 1000, header = 52 }
		local over =
			TopBand.slots({ w = w, h = h, bar = bar, device = "pc", hud = hud, windows = { low }, items = item })
		T.expect(over.rects.toast1.top).toBe(zone.top)
		T.expect(over.rects.toast1.bottom <= low.top - TopBand.GAP).toBe(true)
		-- one pixel less: under the title bar
		local tight: TopBand.Window =
			{ left = 660, top = zone.top + 51 + TopBand.GAP, right = 1260, bottom = 1000, header = 52 }
		local under =
			TopBand.slots({ w = w, h = h, bar = bar, device = "pc", hud = hud, windows = { tight }, items = item })
		T.expect(under.rects.toast1.top).toBe(tight.top + tight.header + TopBand.GAP)
		-- a window at the top: the zone's own place is already under its title bar
		local top: TopBand.Window = { left = 660, top = bar + 8, right = 1260, bottom = 900, header = 52 }
		local onIt =
			TopBand.slots({ w = w, h = h, bar = bar, device = "pc", hud = hud, windows = { top }, items = item })
		T.expect(onIt.rects.toast1.top).toBe(zone.top)
		-- the PC card waits while a window covers its slot
		local wide: TopBand.Window = { left = 0, top = bar + 8, right = w, bottom = h, header = 52 }
		T.expect(
			TopBand.slots({ w = w, h = h, bar = bar, device = "pc", windows = { wide }, items = {}, card = "fight" }).card
		)
			.toBeNil()
		T.expect(TopBand.slots({ w = w, h = h, bar = bar, device = "pc", items = {}, card = "fight" }).card ~= nil)
			.toBe(true)
	end)

	T.it("keeps clear of the tutorial's tile and never moves a shown message up", function()
		local w, h, bar = 1920, 1080, 0
		local zone = TopBand.zone({ w = w, h = h, bar = bar, device = "pc", items = {} })
		local keep = { left = 800, top = zone.top + 10, right = 1100, bottom = zone.top + 90 }
		local list = items("pc")
		local placed = TopBand.slots({ w = w, h = h, bar = bar, device = "pc", keep = keep, items = list })
		for id, r in placed.rects do
			T.expect({ id, TopBand.meets(r, keep) }).toEqual({ id, false })
		end
		-- the banner went: the toasts keep their tops while they show
		local small = { list[1], { id = "banner", w = TopBand.BANNER.w, h = TopBand.BANNER.h }, list[3], list[4] }
		local before = TopBand.slots({ w = w, h = h, bar = bar, device = "pc", items = small })
		local held = { toast1 = before.rects.toast1.top, toast2 = before.rects.toast2.top }
		local rest = { list[1], list[3], list[4] }
		local after = TopBand.slots({ w = w, h = h, bar = bar, device = "pc", items = rest, held = held })
		T.expect(after.rects.toast1.top).toBe(held.toast1)
		T.expect(after.rects.toast2.top).toBe(held.toast2)
		local free = TopBand.slots({ w = w, h = h, bar = bar, device = "pc", items = rest })
		T.expect(free.rects.toast1.top < held.toast1).toBe(true)
	end)

	T.it("fits the card summaries and the prompt on every screen (L6)", function()
		for _, s in screens() do
			if s.device == "pc" then
				for kind in HudZones.CARDS do
					local r = down(HudZones.cardSlot(s.hudW, s.hudH, kind :: HudZones.CardKind), s.bar)
					T.expect({
						s.name,
						kind,
						r.left >= 8 and r.right <= s.w - 8 and r.top >= s.bar + 8 and r.bottom <= s.h - 8,
					}).toEqual({ s.name, kind, true })
				end
			end
			T.expect({ s.name, TopBand.PROMPT.w <= s.w - 16 }).toEqual({ s.name, true })
		end
	end)
end)

return nil
