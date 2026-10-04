--!strict
local Format = require("../src/shared/Util/Format")
local T = require("./Test")

T.describe("Format", function()
	T.it("number groups thousands", function()
		T.expect(Format.number(0)).toBe("0")
		T.expect(Format.number(999)).toBe("999")
		T.expect(Format.number(1000)).toBe("1 000")
		T.expect(Format.number(1234567)).toBe("1 234 567")
		T.expect(Format.number(-45000)).toBe("-45 000")
		T.expect(Format.number(1234, ",")).toBe("1,234")
	end)

	T.it("short abbreviates", function()
		T.expect(Format.short(999)).toBe("999")
		T.expect(Format.short(1000)).toBe("1k")
		T.expect(Format.short(1234)).toBe("1.2k")
		T.expect(Format.short(3400000)).toBe("3.4M")
		T.expect(Format.short(-2500)).toBe("-2.5k")
	end)

	T.it("time formats mm:ss and hh:mm:ss", function()
		T.expect(Format.time(0)).toBe("00:00")
		T.expect(Format.time(75)).toBe("01:15")
		T.expect(Format.time(3725)).toBe("01:02:05")
		T.expect(Format.time(-3)).toBe("00:00")
		T.expect(Format.timeLong(59)).toBe("00:00:59")
	end)
end)

return nil
