--!strict
local Channel = require("../src/shared/Logic/Channel")
local SkillData = require("../src/shared/Data/Skills")
local Skills = require("../src/shared/Logic/Skills")
local T = require("./Test")

T.describe("Channel.stops (S70)", function()
	T.it("damage ends a channel unless steadfast; moving and death always", function()
		T.expect(Channel.stops("channel", "damage", {})).toBe(true)
		T.expect(Channel.stops("channel", "damage", nil)).toBe(true)
		T.expect(Channel.stops("channel", "damage", { steadfast = true })).toBe(false)
		T.expect(Channel.stops("channel", "move", { steadfast = true })).toBe(true)
		T.expect(Channel.stops("channel", "death", { steadfast = true })).toBe(true)
		T.expect(Channel.stops("channel", "move", nil)).toBe(true)
		T.expect(Channel.stops("other", "damage", { steadfast = true })).toBe(true)
	end)

	T.it("Prayer 10B makes the channel steadfast", function()
		local prayer = SkillData.byId.prayer
		local steady = Skills.effective(prayer, 10, { ["prayer:10"] = "b" }, nil, true)
		T.expect(steady.steadfast).toBe(true)
		T.expect(Channel.stops("channel", "damage", steady)).toBe(false)
		local plain = Skills.effective(prayer, 10, nil, nil, true)
		T.expect(plain.steadfast).toBeNil()
		T.expect(Channel.stops("channel", "damage", plain)).toBe(true)
		local chosenA = Skills.effective(prayer, 10, { ["prayer:10"] = "a" }, nil, true)
		T.expect(Channel.stops("channel", "damage", chosenA)).toBe(true)
	end)
end)

return nil
