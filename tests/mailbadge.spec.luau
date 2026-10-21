--!strict
-- Owner 2026-10-21: the mail icon under the attack button shows the parcels waiting (Logic/Mail.badge).

local Mail = require("../src/shared/Logic/Mail")
local T = require("./Test")

T.describe("Mail badge", function()
	T.it("counts the parcels of the state branch", function()
		T.expect(Mail.badge({ list = {}, count = 3 })).toBe(3)
		T.expect(select(2, Mail.badge({ list = {}, count = 3 }))).toBe("3")
		T.expect(select(2, Mail.badge({ count = 12 }))).toBe("9+")
	end)
	T.it("shows no icon without parcels or state", function()
		T.expect(select(2, Mail.badge({ count = 0 }))).toBe(nil)
		T.expect(select(2, Mail.badge(nil))).toBe(nil)
		T.expect(select(2, Mail.badge({ count = "x" }))).toBe(nil)
		T.expect(Mail.badge(nil)).toBe(0)
	end)
	T.it("an empty mailbox shows nothing", function()
		local list = Mail.visible(Mail.newBox(), "c1", 1000000)
		T.expect(select(2, Mail.badge({ list = list, count = #list }))).toBe(nil)
	end)
end)

return nil
