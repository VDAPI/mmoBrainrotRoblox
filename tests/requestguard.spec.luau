--!strict
-- W28: fast clicks never show "error.badRequest": the server's rejection codes and the client's request guard.
local Definitions = require("../src/shared/Net/Definitions")
local RateLimit = require("../src/shared/Logic/RateLimit")
local RequestGuard = require("../src/shared/Logic/RequestGuard")
local pl = require("../src/shared/Data/Localization/pl")
local en = require("../src/shared/Data/Localization/en")
local T = require("./Test")

local function packed(...: any): { n: number, [number]: any }
	return table.pack(...)
end

T.describe("RequestGuard.rejectCode", function()
	T.it("a full rate limit bucket answers rateLimited, never badRequest", function()
		T.expect(RequestGuard.rejectCode(false, true)).toBe("error.rateLimited")
		T.expect(RequestGuard.rejectCode(false, false)).toBe("error.rateLimited")
	end)

	T.it("bad arguments stay badRequest; a good call passes", function()
		T.expect(RequestGuard.rejectCode(true, false)).toBe("error.badRequest")
		T.expect(RequestGuard.rejectCode(true, true)).toBe(nil)
	end)

	T.it("clicking a rate 1 toggle 3 times at once: the third is rateLimited and silent", function()
		local limiter = RateLimit.new(assert(Definitions.SetPvp.rate, "SetPvp has a rate"))
		local codes = {}
		for _ = 1, 3 do
			table.insert(codes, RequestGuard.rejectCode(limiter:take("1", 0), true) or "ok")
		end
		T.expect(codes).toEqual({ "ok", "ok", "error.rateLimited" })
		T.expect(RequestGuard.isSilent(codes[3])).toBe(true)
	end)

	T.it("silent keys are tooFast, rateLimited and stale; badRequest is not silent", function()
		T.expect(RequestGuard.isSilent("error.tooFast")).toBe(true)
		T.expect(RequestGuard.isSilent("error.rateLimited")).toBe(true)
		T.expect(RequestGuard.isSilent("error.stale")).toBe(true)
		T.expect(RequestGuard.isSilent("error.badRequest")).toBe(false)
		T.expect(RequestGuard.isSilent(nil)).toBe(false)
	end)

	T.it("every silent key has a text in both languages", function()
		for key in RequestGuard.SILENT do
			T.expect(type((pl :: any)[key])).toBe("string")
			T.expect(type((en :: any)[key])).toBe("string")
		end
	end)
end)

T.describe("RequestGuard.key", function()
	T.it("is the same for the same call and differs by remote and arguments", function()
		local a = RequestGuard.key("UseItem", { 5 }, 1)
		T.expect(a).toBe(RequestGuard.key("UseItem", { 5 }, 1))
		T.expect(a == RequestGuard.key("UseItem", { 6 }, 1)).toBe(false)
		T.expect(a == RequestGuard.key("DestroyItem", { 5 }, 1)).toBe(false)
		T.expect(RequestGuard.key("X", { 1 }, 1) == RequestGuard.key("X", { "1" }, 1)).toBe(false)
		T.expect(RequestGuard.key("X", { nil, 1 }, 2) == RequestGuard.key("X", { 1 }, 1)).toBe(false)
	end)

	T.it("keys tables by content, whatever the insertion order", function()
		local one = RequestGuard.key("Sell", { "npc", { 3, 4 } }, 2)
		T.expect(one).toBe(RequestGuard.key("Sell", { "npc", { 3, 4 } }, 2))
		T.expect(one == RequestGuard.key("Sell", { "npc", { 4, 3 } }, 2)).toBe(false)
		local x = { str = 1, dex = 2 }
		local y = {}
		y.dex = 2
		y.str = 1
		T.expect(RequestGuard.key("AllocateStats", { x }, 1)).toBe(RequestGuard.key("AllocateStats", { y }, 1))
	end)

	T.it("gives up (nil) on deep tables and odd values", function()
		T.expect(RequestGuard.key("X", { { { { 1 } } } }, 1)).toBe(nil)
		T.expect(RequestGuard.key("X", { print }, 1)).toBe(nil)
	end)
end)

T.describe("RequestGuard verdicts", function()
	T.it("a second identical call while the first is in flight joins it", function()
		local g = RequestGuard.new()
		local key = RequestGuard.key("UseItem", { 3 }, 1)
		T.expect(g:begin("UseItem", key, nil, 0)).toBe("send")
		T.expect(g:begin("UseItem", key, nil, 0.05)).toBe("join")
		T.expect(g:pending(assert(key, "key"), 0.05)).toBe(true)
		g:finish(key, packed(true, nil), 0.1)
		T.expect(g:pending(assert(key, "key"), 0.1)).toBe(false)
		T.expect(assert(g:results(assert(key, "key")), "results")[1]).toBe(true)
	end)

	T.it("a repeat right after the answer reuses it; later it is sent again", function()
		local g = RequestGuard.new()
		local key = RequestGuard.key("UseItem", { 3 }, 1)
		g:begin("UseItem", key, nil, 0)
		g:finish(key, packed(true), 0.1)
		T.expect(g:begin("UseItem", key, nil, 0.1 + RequestGuard.SAME_WINDOW / 2)).toBe("reuse")
		T.expect(g:begin("UseItem", key, nil, 0.1 + RequestGuard.SAME_WINDOW + 0.01)).toBe("send")
	end)

	T.it("other arguments of an ordinary remote are sent at once", function()
		local g = RequestGuard.new()
		T.expect(g:begin("UseItem", RequestGuard.key("UseItem", { 3 }, 1), nil, 0)).toBe("send")
		T.expect(g:begin("UseItem", RequestGuard.key("UseItem", { 4 }, 1), nil, 0.01)).toBe("send")
	end)

	T.it("a repeatable remote is sent again right after the answer, but still joins while in flight", function()
		local g = RequestGuard.new()
		local opts = { repeatable = true }
		local key = RequestGuard.key("Buy", { "npc", "potion", 1 }, 3)
		T.expect(g:begin("Buy", key, opts, 0)).toBe("send")
		T.expect(g:begin("Buy", key, opts, 0.01)).toBe("join")
		g:finish(key, packed(true), 0.05)
		T.expect(g:begin("Buy", key, opts, 0.06)).toBe("send")
	end)

	T.it("a toggle flipped back within the window is dropped, later it goes", function()
		local g = RequestGuard.new()
		local opts = { toggle = true }
		local on = RequestGuard.key("AutoGrind", { true }, 1)
		local off = RequestGuard.key("AutoGrind", { false }, 1)
		T.expect(g:begin("AutoGrind", on, opts, 0)).toBe("send")
		g:finish(on, packed(true), 0.05)
		T.expect(g:begin("AutoGrind", off, opts, 0.1)).toBe("drop")
		T.expect(g:begin("AutoGrind", off, opts, RequestGuard.TOGGLE_WINDOW + 0.01)).toBe("send")
	end)

	T.it("a call stuck in flight stops holding its twins after INFLIGHT_MAX", function()
		local g = RequestGuard.new()
		local key = RequestGuard.key("MailRefresh", {}, 0)
		g:begin("MailRefresh", key, nil, 0)
		T.expect(g:begin("MailRefresh", key, nil, 1)).toBe("join")
		T.expect(g:begin("MailRefresh", key, nil, RequestGuard.INFLIGHT_MAX + 1)).toBe("send")
	end)

	T.it("finished results are pruned after a while", function()
		local g = RequestGuard.new()
		local key = assert(RequestGuard.key("UseItem", { 1 }, 1), "key")
		g:begin("UseItem", key, nil, 0)
		g:finish(key, packed(true), 0)
		g:begin("Other", nil, nil, 10)
		T.expect(g:results(key)).toBe(nil)
	end)
end)

T.describe("Definitions W28 flags", function()
	T.it("toggles and repeatables are functions; no remote is both", function()
		local toggles = 0
		for name, def in Definitions do
			if def.toggle or def.repeatable then
				T.expect(`{name}:{def.kind}`).toBe(`{name}:function`)
			end
			T.expect(`{name}:{def.toggle == true and def.repeatable == true}`).toBe(`{name}:false`)
			if def.toggle then
				toggles += 1
			end
		end
		T.expect(toggles > 0).toBe(true)
		T.expect(Definitions.SetPvp.toggle).toBe(true)
		T.expect(Definitions.AutoGrind.toggle).toBe(true)
		T.expect(Definitions.CastSkill.repeatable).toBe(true)
	end)
end)
